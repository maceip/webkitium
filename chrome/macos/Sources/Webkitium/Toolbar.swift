import SwiftUI

/// The window toolbar. Matches Safari's layout exactly:
///   • Left:   `[< | >]`  back/forward in one Liquid Glass pill with hairline divider.
///   • Center: URL field — reader/search/text/reload, with autocomplete dropdown.
///   • Right:  `[⊕ ⇧ + ▢ ↓]` — extensions / share / new tab / overview / downloads in one
///             glass pill.
struct TopToolbar: ToolbarContent {
    @Environment(BrowserViewModel.self) private var browser

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) { backForwardPill }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .principal) {
            URLFieldView().frame(minWidth: 360, idealWidth: 720, maxWidth: 900)
        }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .primaryAction) { rightClusterPill }
    }

    // MARK: - Back / Forward pill

    private var backForwardPill: some View {
        HStack(spacing: 0) {
            Button { browser.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(!browser.canGoBack)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)

            Button { browser.goForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .disabled(!browser.canGoForward)
        }
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Right cluster pill — extensions, share, +, overview, downloads

    private var rightClusterPill: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 4) {
            Button { browser.showExtensionsPopover.toggle() } label: {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .popover(isPresented: $browserBinding.showExtensionsPopover, arrowEdge: .bottom) {
                ExtensionsPopover(
                    onManage: { openSettings(target: .extensions) },
                    onStore:  { openSettings(target: .extensionsStore) })
                    .frame(width: 320)
            }
            .contextMenu {
                Button("Manage Extensions…") { openSettings(target: .extensions) }
                Button("More Extensions in Store…") { openSettings(target: .extensionsStore) }
                Divider()
                Button("Hide Extensions Button") { }
            }

            ShareToolbarButton()

            AddToDockToolbarButton()

            Button { browser.newTab() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)

            Button {
                withAnimation(.smooth) { browser.showTabs.toggle() }
            } label: {
                Image(systemName: "square.on.square")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)

            DownloadsToolbarButton()
        }
        .glassEffect(.regular, in: .capsule)
    }

    private func openSettings(target: SettingsTarget) {
        NotificationCenter.default.post(name: .openSettingsTarget,
                                        object: nil, userInfo: ["target": target])
        browser.showExtensionsPopover = false
    }
}

/// Toolbar entry for the macOS Sonoma+ "Add to Dock" web-app prompt. Local `@State` for
/// the popover so it anchors correctly to the button icon (vs. presenting as a sheet
/// from the menu).
private struct AddToDockToolbarButton: View {
    @State private var showing = false
    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "rectangle.dock")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.borderless)
        .help("Add to Dock")
        .popover(isPresented: $showing, arrowEdge: .bottom) { AddToDockPopover() }
    }
}
