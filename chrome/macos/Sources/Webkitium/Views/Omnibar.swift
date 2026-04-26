// Omnibar — macOS implementation of design/components/omnibar/SPEC.md.
//
// Interaction contract is shared with chrome/windows/src/Omnibar.xaml:
// [lockmark] [input with placeholder] [reload | extensions | overflow].
// Visual tokens consumed via PaletteProvider. ⌘L focuses from anywhere
// in the app (wired via .focused() + global key binding).

import SwiftUI

struct Omnibar: View {
    @EnvironmentObject private var palette: PaletteProvider
    @Environment(\.colorScheme) private var colorScheme

    @State private var text: String = ""
    @State private var suggestions: [OmnibarSuggestion] = []
    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    var onSubmit: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        palette.semantic(.accentFill, colorScheme: colorScheme)
                    )

                TextField("Search or enter address", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .focused($isFocused)
                    .onSubmit {
                        navigateToText()
                    }
                    .onChange(of: text) { newValue in
                        updateSuggestions(for: newValue)
                    }
                    .onChange(of: isFocused) { focused in
                        showSuggestions = focused && !suggestions.isEmpty
                    }

                actionButton(systemName: "arrow.clockwise", help: "Reload (⌘R)") {
                    NotificationCenter.default.post(name: .reloadCommand, object: nil)
                }
                actionButton(systemName: "puzzlepiece.extension", help: "Extensions") {}
                actionButton(systemName: "ellipsis", help: "More") {}
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        palette.semantic(.surfaceSunken,
                                         colorScheme: colorScheme)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        palette.semantic(
                            isFocused ? .borderFocus : .borderSubtle,
                            colorScheme: colorScheme
                        ),
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .animation(.easeOut(duration: 0.12), value: isFocused)

            if showSuggestions && !suggestions.isEmpty {
                suggestionsList
            }
        }
    }

    private var suggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button {
                    text = suggestion.url
                    navigateToText()
                    showSuggestions = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: suggestion.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(palette.semantic(.textPrimary, colorScheme: colorScheme))
                                .lineLimit(1)
                            Text(suggestion.url)
                                .font(.system(size: 10))
                                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.semantic(.surfaceSunken, colorScheme: colorScheme))
        )
        .padding(.top, 4)
    }

    private func navigateToText() {
        isFocused = false
        showSuggestions = false
        onSubmit?(text)
    }

    private func updateSuggestions(for query: String) {
        let defaultSuggestions: [OmnibarSuggestion] = [
            .init(icon: "globe", title: "Hacker News", url: "https://news.ycombinator.com"),
            .init(icon: "globe", title: "Google", url: "https://google.com"),
            .init(icon: "globe", title: "DuckDuckGo", url: "https://duckduckgo.com"),
            .init(icon: "doc.text", title: "Wikipedia", url: "https://wikipedia.org"),
        ]

        if query.isEmpty {
            suggestions = defaultSuggestions
        } else {
            let q = query.lowercased()
            suggestions = defaultSuggestions.filter {
                $0.title.lowercased().contains(q) || $0.url.lowercased().contains(q)
            }
        }
        showSuggestions = isFocused && !suggestions.isEmpty
    }

    @ViewBuilder
    private func actionButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(
                    palette.semantic(.textTertiary,
                                     colorScheme: colorScheme)
                )
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

struct OmnibarSuggestion: Identifiable {
    let id = UUID()
    var icon: String
    var title: String
    var url: String
}
