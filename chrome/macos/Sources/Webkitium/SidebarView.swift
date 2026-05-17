import SwiftUI

/// Sidebar — header icon row (new-tab-group + hide-sidebar), "N Tabs" pill,
/// tab groups bar, tabs list, "Saved" leaves, profile footer chip.
///
/// The header icons sit AT the same Y as the back/forward pill on the detail
/// side. To get that, the VStack uses `.ignoresSafeArea(.container, edges: .top)`
/// so the sidebar's content area extends UP to the window's top edge (under the
/// translucent titlebar) — the first row of the VStack then lands in the
/// titlebar Y range, on the sidebar side of the column divider, matching the
/// gold-standard Safari reference (LOOK.png / image #27).
///
/// The sidebar must show a visible right edge as a 1px hairline (matches the
/// top edge, see Safari reference).
struct SidebarView: View {
    @Environment(BrowserViewModel.self) private var browser
    let tabMorph: Namespace.ID

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            sidebarHeaderIcons
            if browser.isPrivate {
                HStack { PrivateModeBadge(); Spacer() }
                    .padding(.horizontal, 10).padding(.top, 6)
            }
            tabsHeaderPill
                .padding(.horizontal, 8)
                .padding(.top, 6)
            TabGroupsBar()

            List(selection: $browserBinding.sidebarSelection) {
                Section {
                    ForEach(browser.visibleTabs) { tab in
                        TabSidebarRow(tab: tab)
                            .tag(SidebarSelection.tab(tab.id))
                            .contextMenu { tabContextMenu(for: tab) }
                            .onHover { hovering in
                                // Hover-URL → status bar overlay.
                                browser.hoveredLink = hovering ? tab.url : nil
                            }
                    }
                }
                Section {
                    ForEach(SidebarLeaf.allCases) { leaf in
                        Label(leaf.title, systemImage: leaf.symbol)
                            .font(.system(size: 12))
                            .tag(SidebarSelection.leaf(leaf))
                            .contextMenu { leafContextMenu(for: leaf) }
                    }
                } header: {
                    Text("saved")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, 22)

            Divider()
            ProfileFooter()
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        // Per spec: visible 1px hairline on the trailing edge of the sidebar so the
        // boundary with the detail column reads clearly (matches the top edge that's
        // already visible). The system separator from NavigationSplitView sometimes
        // disappears under our backgroundExtensionEffect tab strip; this overlay
        // guarantees it.
        .overlay(alignment: .trailing) {
            // Opacity 0.14 was barely visible against the translucent sidebar
            // material — bumped to 0.34 so the divider reads clearly, matching
            // Safari's column edge.
            Rectangle()
                .fill(Color.primary.opacity(0.34))
                .frame(width: 1)
        }
        // Extend the sidebar's content area up to the window's top edge so the
        // first row (sidebarHeaderIcons) lands in the titlebar Y, matching the
        // back/forward pill on the detail side. Without this the VStack starts
        // BELOW the toolbar and the icons sit a row too low.
        .ignoresSafeArea(.container, edges: .top)
        // The ignoresSafeArea above was collapsing the sidebar's intrinsic
        // width — navigationSplitViewColumnWidth's hints were getting silently
        // ignored. An explicit frame minWidth re-asserts the width.
        .frame(minWidth: 700)
    }

    /// Sidebar header: new-tab-group + hide-sidebar. Trailing-aligned, sized to
    /// the toolbar row height so it lines up with back/forward across the
    /// divider. The leading `Spacer(minLength: 70)` reserves space for the
    /// traffic-light controls. Inner targets use Image + `.onTapGesture`
    /// (no Button chrome) — matches the chrome-less treatment of the
    /// back/forward chevrons in the detail toolbar.
    private var sidebarHeaderIcons: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 70)
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 22)
                .help("New Tab Group")
            // Real Button — onTapGesture on a bare Image lost clicks to the
            // NSWindow drag handler in the titlebar Y region. `.borderless`
            // style means no visible chrome on hover.
            Button {
                browser.sidebarVisibility =
                    (browser.sidebarVisibility == .all) ? .detailOnly : .all
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Hide Sidebar")
        }
        .padding(.trailing, 10)
        .frame(height: 38)
    }

    private var tabsHeaderPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 11))
            // Show count of currently-visible tabs so the badge updates with the group
            // filter.
            Text("\(browser.visibleTabs.count) Tabs")
                .font(.system(size: 12, weight: .medium))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(SafariTheme.pillBorder, lineWidth: 1)
        )
    }

    // MARK: - Context menus

    @ViewBuilder
    private func tabContextMenu(for tab: Tab) -> some View {
        Button("New Tab")        { browser.newTab() }
        Button("Duplicate Tab")  { browser.duplicate(tab) }
        Divider()
        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { browser.togglePin(tab) }
        if tab.audio != .none {
            Button(tab.audio == .muted ? "Unmute Tab" : "Mute Tab") { browser.toggleMute(tab) }
        }
        Divider()
        Button("Close Tab",        role: .destructive) { browser.close(tab: tab) }
        Button("Close Other Tabs", role: .destructive) { browser.closeOthers(keeping: tab) }
    }

    @ViewBuilder
    private func leafContextMenu(for leaf: SidebarLeaf) -> some View {
        Button("Open") { browser.sidebarSelection = .leaf(leaf) }
        Button("Open in New Tab") { browser.newTab() }
    }
}

private struct TabSidebarRow: View {
    let tab: Tab

    var body: some View {
        HStack(spacing: 6) {
            if tab.isLoading {
                ProgressView().progressViewStyle(.circular).controlSize(.mini)
                    .frame(width: 14, height: 14)
            } else {
                tab.favicon.view(size: 14)
            }
            Text(tab.title)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if tab.audio == .playing {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            } else if tab.audio == .muted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
