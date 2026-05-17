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
        // When the sidebar is hidden there's no way to restore it from inside
        // the sidebar itself (it's gone). Surface a restore button at the
        // very leading edge of the toolbar in that state only — in ITS OWN
        // Liquid Glass capsule, separate from back/forward. The `ToolbarSpacer
        // (.fixed)` below is what forces Tahoe to render them as two distinct
        // glass pills instead of bundling them together.
        // Sidebar-hidden state — a self-contained Liquid Glass pill with
        // sidebar.left + chevron-down. Explicit `.glassEffect(.regular, in:
        // .capsule)` forces Tahoe to render this as its OWN pill, separate
        // from the back/forward pill that follows. Without explicit glass,
        // both .navigation ToolbarItems get auto-grouped into one capsule.
        // Sidebar restore + back/forward as SEPARATE ToolbarItems at
        // `.navigation`, each with explicit `.glassEffect(.regular, in:
        // .capsule)`. ToolbarSpacer(.fixed) between them. This forces Tahoe
        // to render two distinct Liquid Glass capsules — auto-grouping is
        // broken by the explicit glass plus the spacer.
        ToolbarItem(placement: .navigation) {
            if browser.sidebarVisibility != .all {
                HStack(spacing: 8) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16, weight: .regular))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 42)
                .padding(.horizontal, 14)
                .glassEffect(.regular, in: .capsule)
                .contentShape(Capsule())
                .onTapGesture { browser.sidebarVisibility = .all }
                .help("Show Sidebar")
            }
        }

        // Explicit-width spacer item — ToolbarSpacer(.fixed) was giving a
        // visibly-too-tight gap between the sidebar-restore pill and the
        // back/forward pill. A Color.clear ToolbarItem with a frame width
        // sets the gap precisely.
        ToolbarItem(placement: .navigation) {
            Color.clear.frame(width: 18, height: 1)
        }

        ToolbarItem(placement: .navigation) { backForwardPill }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .principal) {
            URLFieldView().frame(minWidth: 280, idealWidth: 480, maxWidth: 560)
        }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .primaryAction) { rightClusterPill }
    }

    // MARK: - Back / Forward pill

    @ViewBuilder
    private var backForwardPill: some View {
        // Per target images (THIS.png / THIS2.png): the back/forward pill
        // only renders its Liquid Glass capsule when the sidebar is VISIBLE.
        // When the sidebar is hidden, the chevrons render freestanding with
        // no capsule — that visual emphasis goes to the sidebar-restore pill
        // instead.
        if browser.sidebarVisibility == .all {
            backForwardContent
                .glassEffect(.regular, in: .capsule)
        } else {
            backForwardContent
        }
    }

    private var backForwardContent: some View {
        HStack(spacing: 0) {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .regular))
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
                .foregroundStyle(browser.canGoBack ? .primary : .tertiary)
                .onTapGesture { if browser.canGoBack { browser.goBack() } }

            Rectangle()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 1, height: 14)

            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .regular))
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
                .foregroundStyle(browser.canGoForward ? .primary : .tertiary)
                .onTapGesture { if browser.canGoForward { browser.goForward() } }
        }
    }

    // MARK: - Right cluster pill — extensions, share, +, overview, downloads

    private var rightClusterPill: some View {
        // Per spec: share / new tab / overview as the always-present trio.
        // Downloads is contextual — only while in-flight. Per-extension
        // buttons appear leading-of the trio for every enabled extension
        // whose manifest declared `hasToolbarButton` (the standard browser
        // action surface).
        return HStack(spacing: 0) {
            PerExtensionToolbarButtons()

            if hasInFlightDownload {
                DownloadsToolbarButton()
                    .frame(width: 44, height: 42)
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }

            ShareToolbarButton()
                .disabled(browser.selectedTab == nil)

            Image(systemName: "plus")
                .font(.system(size: 15, weight: .regular))
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
                .onTapGesture { browser.newTab() }

            Image(systemName: "square.on.square")
                .font(.system(size: 15, weight: .regular))
                .frame(width: 44, height: 42)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth) { browser.showTabs.toggle() }
                }
        }
        .animation(.smooth(duration: 0.18), value: hasInFlightDownload)
        // No explicit `.glassEffect(...)` — see note on backForwardPill.
    }

    /// True when at least one download is still in progress. Drives the
    /// conditional render of `DownloadsToolbarButton` — completed-only history
    /// is reachable through the Window menu, not the toolbar.
    private var hasInFlightDownload: Bool {
        browser.downloads.contains { !$0.isCompleted }
    }

    private func openSettings(target: SettingsTarget) {
        NotificationCenter.default.post(name: .openSettingsTarget,
                                        object: nil, userInfo: ["target": target])
        browser.showExtensionsPopover = false
    }
}

