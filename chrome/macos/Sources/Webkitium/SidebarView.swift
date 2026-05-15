import SwiftUI

/// Sidebar — top icon row (new-tab-group disabled, hide-sidebar), "N Tabs" pill,
/// tab groups bar, tabs list, "Saved" leaves, profile footer chip.
///
/// **Locked spec:** see `design/toolbar-spec.md` — the two top icons (new-tab-group
/// + hide-sidebar) live HERE on the sidebar header, NOT on the window toolbar.
/// The sidebar must show a visible right edge as a 1px hairline (matches the top
/// edge, see Safari reference).
struct SidebarView: View {
    @Environment(BrowserViewModel.self) private var browser
    let tabMorph: Namespace.ID

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            // Sidebar header icons — ON THE SIDEBAR (not in the window toolbar).
            // Per spec: new-tab-group (disabled, Tab Groups not built) + hide-sidebar,
            // anchored to the trailing edge of the sidebar's top row.
            sidebarHeaderIcons
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 4)
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
            Rectangle()
                .fill(Color.primary.opacity(0.14))
                .frame(width: 1)
        }
    }

    /// Sidebar header: new-tab-group (disabled — Tab Groups not built) + hide-sidebar.
    /// Trailing-aligned so the icons sit clear of the system traffic-light reserve at
    /// the leading edge. Inner targets are Image + .onTapGesture (no Button chrome).
    private var sidebarHeaderIcons: some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)        // visibly disabled
                .frame(width: 22, height: 22)
                .help("New Tab Group")
            Image(systemName: "sidebar.left")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth) {
                        browser.sidebarVisibility =
                            (browser.sidebarVisibility == .all) ? .detailOnly : .all
                    }
                }
                .help("Hide Sidebar")
        }
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
