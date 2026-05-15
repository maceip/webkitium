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
        // Per spec: the two sidebar-header icons (new-tab-group disabled +
        // hide-sidebar) sit in the toolbar at the leading edge, next to the
        // traffic lights, on the SAME row as back/forward. They look like
        // "sidebar icons" because they govern the sidebar, but the actual
        // SwiftUI placement is the navigation toolbar slot.
        ToolbarItem(placement: .navigation) { sidebarIconPill }

        // Force a separator so the macOS 26 toolbar doesn't fuse these two
        // ToolbarItems into one visual pill — they need to read as two
        // distinct glass capsules per the spec reference.
        ToolbarSpacer(.fixed, placement: .navigation)

        ToolbarItem(placement: .navigation) { backForwardPill }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .principal) {
            URLFieldView().frame(minWidth: 360, idealWidth: 720, maxWidth: 900)
        }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .primaryAction) { rightClusterPill }
    }

    // MARK: - Sidebar-header icons (in the toolbar at .navigation placement)

    private var sidebarIconPill: some View {
        // Two icons: new tab group (disabled — Tab Groups not built) + hide
        // sidebar. Inner targets are Image + onTapGesture (NOT Button) so the
        // OS-supplied button chrome can't draw top/bottom border lines inside
        // the glass pill.
        HStack(spacing: 0) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)        // visibly disabled
                .frame(width: 28, height: 22)
                .help("New Tab Group")

            Image(systemName: "sidebar.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth) {
                        browser.sidebarVisibility =
                            (browser.sidebarVisibility == .all) ? .detailOnly : .all
                    }
                }
                .help("Hide Sidebar")
        }
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Back / Forward pill

    private var backForwardPill: some View {
        // Per spec: only the pill is the border. Earlier `.buttonStyle(.plain)`
        // attempt still left visible button chrome (top/bottom hover bands inside
        // the pill). Switching to Image + .onTapGesture removes ALL button chrome
        // — the icon is just a tap-targetable shape with NO framework-supplied
        // hover/border treatment.
        HStack(spacing: 0) {
            Image(systemName: "chevron.left")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .foregroundStyle(browser.canGoBack ? .primary : .tertiary)
                .onTapGesture { if browser.canGoBack { browser.goBack() } }

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .foregroundStyle(browser.canGoForward ? .primary : .tertiary)
                .onTapGesture { if browser.canGoForward { browser.goForward() } }
        }
        .glassEffect(.regular, in: .capsule)
    }

    // MARK: - Right cluster pill — extensions, share, +, overview, downloads

    private var rightClusterPill: some View {
        // Per spec: exactly 3 icons. Share / new tab / overview. Share disables when
        // there's no active page. Inner targets are Image + .onTapGesture for the
        // same no-chrome reason as backForwardPill. (ShareToolbarButton remains a
        // Button internally because it owns a popover; revisit if it shows the
        // same edge artifact.)
        return HStack(spacing: 0) {
            ShareToolbarButton()
                .disabled(browser.selectedTab == nil)

            Image(systemName: "plus")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .onTapGesture { browser.newTab() }

            Image(systemName: "square.on.square")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth) { browser.showTabs.toggle() }
                }
        }
        .glassEffect(.regular, in: .capsule)
    }

    private func openSettings(target: SettingsTarget) {
        NotificationCenter.default.post(name: .openSettingsTarget,
                                        object: nil, userInfo: ["target": target])
        browser.showExtensionsPopover = false
    }
}

