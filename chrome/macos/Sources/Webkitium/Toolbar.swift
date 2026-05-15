import SwiftUI

/// The window toolbar. **Locked spec:** `design/toolbar-spec.md`
/// (single source of truth — change that file + the reference PNG
/// BEFORE changing this code).
///
///   • Left:   `[< >]`     back/forward in one Liquid Glass pill, **no internal divider**.
///   • Center: URL field   — cursor leading-aligned when focused.
///   • Right:  `[⇧ + ▢]`   share / new tab / overview. **3 icons only.**
///                          Share greys out when there's no active page.
///                          Extensions / downloads / add-to-dock are NOT in the toolbar
///                          (menu-reachable only) per the spec.
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
        // Per spec: the **pill** is the only border. Inner buttons must NOT draw their
        // own top/bottom edges. `.buttonStyle(.plain)` strips all chrome — `.borderless`
        // still rendered hover/pressed bands that showed up as horizontal lines.
        HStack(spacing: 0) {
            Button { browser.goBack() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!browser.canGoBack)

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)

            Button { browser.goForward() } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!browser.canGoForward)
        }
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Right cluster pill — extensions, share, +, overview, downloads

    private var rightClusterPill: some View {
        // Per spec: exactly 3 icons. Share / new tab / overview. Share disables when
        // there's no active page. Inner buttons use `.plain` so the pill is the only
        // border (same rationale as backForwardPill).
        return HStack(spacing: 0) {
            ShareToolbarButton()
                .disabled(browser.selectedTab == nil)

            Button { browser.newTab() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.smooth) { browser.showTabs.toggle() }
            } label: {
                Image(systemName: "square.on.square")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .glassEffect(.regular, in: .capsule)
    }

    private func openSettings(target: SettingsTarget) {
        NotificationCenter.default.post(name: .openSettingsTarget,
                                        object: nil, userInfo: ["target": target])
        browser.showExtensionsPopover = false
    }
}

