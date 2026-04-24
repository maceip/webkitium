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
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Lockmark. SF Symbol `lock.fill`. Color follows accent so
            // the brand hue is visible at the point of identity.
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    palette.semantic(.accentFill, colorScheme: colorScheme)
                )

            // Input. Borderless; the pill container owns the visual.
            TextField("Search or enter address", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .onSubmit {
                    // Stub -- wires into BrowserCommandController when
                    // the core's C++/Swift bridge lands.
                    isFocused = false
                }

            // Trailing action cluster.
            actionButton(systemName: "arrow.clockwise", help: "Reload (⌘R)")
            actionButton(systemName: "puzzlepiece.extension", help: "Extensions")
            actionButton(systemName: "ellipsis", help: "More")
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
    }

    @ViewBuilder
    private func actionButton(systemName: String, help: String) -> some View {
        Button {
            // Stub
        } label: {
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
