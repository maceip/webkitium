import SwiftUI

/// Find on page bar — slides down below the toolbar when activated (Cmd+F). Matches the
/// reference screenshots:
///
///   [ Begins with ▾ ]  [ 🔍  Search                          ]  [ ‹ | › ]  [ Done ]
///
/// The "Begins with" popup is a custom popover (not a system Menu), with each row a
/// hand-rolled selectable pill: the **selected** row is painted with an accent-colored
/// rounded-pill background and shows a leading checkmark; the unselected row is plain.
struct FindOnPageBar: View {
    @Environment(BrowserViewModel.self) private var browser
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var browserBinding = browser
        HStack(spacing: 8) {
            FindModeTrigger()
            searchField
            stepArrows
            doneButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .bottom)
        .onAppear { fieldFocused = true }
    }

    // MARK: - Search field

    private var searchField: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Search", text: $browserBinding.findText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($fieldFocused)
                .onSubmit { browser.nextFindMatch() }
                .onChange(of: browser.findText) { _, _ in browser.recomputeFindMatches() }
            if browser.findMatchCount > 0 {
                Text("\(browser.findCurrentIndex) of \(browser.findMatchCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(.thinMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.accentColor.opacity(fieldFocused ? 0.85 : 0),
                        lineWidth: fieldFocused ? 1.5 : 0)
        )
        .animation(.smooth(duration: 0.2), value: fieldFocused)
        .frame(minWidth: 320, idealWidth: 520, maxWidth: 720)
    }

    private var stepArrows: some View {
        HStack(spacing: 0) {
            Button { browser.previousFindMatch() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 22)
                    .foregroundStyle(browser.findMatchCount > 0 ? .primary : .tertiary)
            }
            .buttonStyle(.borderless)
            .disabled(browser.findMatchCount == 0)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 12)

            Button { browser.nextFindMatch() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .frame(width: 24, height: 22)
                    .foregroundStyle(browser.findMatchCount > 0 ? .primary : .tertiary)
            }
            .buttonStyle(.borderless)
            .disabled(browser.findMatchCount == 0)
        }
        .background(.thinMaterial, in: Capsule(style: .continuous))
    }

    private var doneButton: some View {
        Button("Done") { browser.closeFindBar() }
            .keyboardShortcut(.escape, modifiers: [])
    }
}

// MARK: - Mode trigger + custom popover

/// Trigger button styled like a popup ("Begins with ⌄") that opens a custom popover
/// instead of the system `Menu`. The popover renders each option as a hand-rolled row so
/// we can match Safari's pill-with-checkmark selection style exactly.
private struct FindModeTrigger: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var showPicker = false

    var body: some View {
        Button { showPicker.toggle() } label: {
            HStack(spacing: 6) {
                Text(browser.findMode.title).font(.system(size: 13))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 24)
        }
        .buttonStyle(.borderless)
        .background(.thinMaterial,
                     in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .popover(isPresented: $showPicker, arrowEdge: .bottom) {
            FindModePopover(selected: browser.findMode) { mode in
                browser.findMode = mode
                browser.recomputeFindMatches()
                showPicker = false
            }
        }
    }
}

/// Hand-rolled mode-picker popover. Selected row → accent-colored pill background with
/// a leading checkmark; unselected row → plain text. Hover-highlight on both rows.
private struct FindModePopover: View {
    let selected: FindMode
    let onSelect: (FindMode) -> Void
    @State private var hoveredMode: FindMode?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(FindMode.allCases) { mode in
                row(mode)
            }
        }
        .padding(6)
        .frame(width: 180)
    }

    private func row(_ mode: FindMode) -> some View {
        let isSelected = mode == selected
        let isHovered = hoveredMode == mode

        return Button {
            onSelect(mode)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 12)
                Text(mode.title).font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor :
                          (isHovered ? Color.primary.opacity(0.08) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredMode = $0 ? mode : nil }
    }
}
