import SwiftUI

/// Horizontal tab strip below the URL bar. Renders pinned tabs (narrow, icon-only) on
/// the leading side, then unpinned tabs sized via the decompiled `computeButtonWidths`
/// algorithm. Edge fade gradients indicate hidden tabs when the strip overflows.
struct TabStripView: View {
    @Environment(BrowserViewModel.self) private var browser
    let tabMorph: Namespace.ID

    // Drive off `visibleTabs` so a Tab Group filter narrows the strip; pinned tabs are
    // global and always show.
    private var pinned: [Tab]   { browser.visibleTabs.filter { $0.isPinned } }
    private var unpinned: [Tab] { browser.visibleTabs.filter { !$0.isPinned } }

    var body: some View {
        if browser.visibleTabs.count > 1 {
            GeometryReader { geo in
                let pinnedWidth: CGFloat = CGFloat(pinned.count) * 38
                let unpinnedAvailable = max(geo.size.width - pinnedWidth - 8, 0)
                let widths = SafariDecompiled.computeButtonWidths(
                    numberOfButtons: unpinned.count,
                    selectedIndex: unpinned.firstIndex(where: { $0.id == browser.selectedTabID }),
                    inWidth: unpinnedAvailable)
                let needsLeftFade = pinnedWidth > 0
                let needsRightFade =
                    unpinned.reduce(0.0, { $0 + (($1.id == browser.selectedTabID)
                                                ? widths.selected + widths.remainder
                                                : widths.other) }) > unpinnedAvailable + 4

                HStack(spacing: 1) {
                    ForEach(pinned) { tab in
                        PinnedTabCell(tab: tab, tabMorph: tabMorph)
                    }
                    ForEach(unpinned) { tab in
                        let isSelected = tab.id == browser.selectedTabID
                        let w = isSelected
                            ? widths.selected + widths.remainder - 1
                            : widths.other - 1
                        TabStripCell(tab: tab, isSelected: isSelected, tabMorph: tabMorph)
                            .frame(width: w)
                    }
                }
                .overlay(alignment: .leading) {
                    if needsLeftFade {
                        // Fade matches the strip's background material so hidden tabs
                        // dissolve into the chrome — adapts to light/dark mode.
                        LinearGradient(stops: [
                            .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.85), location: 0),
                            .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.0), location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28).allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .trailing) {
                    if needsRightFade {
                        LinearGradient(stops: [
                            .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.0), location: 0),
                            .init(color: Color(nsColor: .windowBackgroundColor).opacity(0.85), location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                            .frame(width: 28).allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 36)
            .background(.regularMaterial)
        }
    }
}

private struct TabStripCell: View {
    let tab: Tab
    let isSelected: Bool
    let tabMorph: Namespace.ID
    @Environment(BrowserViewModel.self) private var browser
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            closeOrFaviconLeading
            Text(tab.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            audioControl
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.vertical, 3)
        )
        .onHover { hovering = $0 }
        .onTapGesture { browser.select(tab: tab) }
        .matchedGeometryEffect(id: tab.id, in: tabMorph, isSource: !browser.showTabs)
        .contextMenu { tabContextMenu }
    }

    /// Left slot — close X on hover (with hover ring), otherwise favicon or progress spinner.
    @ViewBuilder
    private var closeOrFaviconLeading: some View {
        ZStack {
            if hovering {
                Button {
                    withAnimation(.smooth) { browser.close(tab: tab) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .frame(width: 14, height: 14)
                        .background(Color.primary.opacity(0.12),
                                     in: Circle())
                }
                .buttonStyle(.borderless)
            } else if tab.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
            } else {
                tab.favicon.view(size: 14)
            }
        }
        .frame(width: 14, height: 14)
    }

    /// Right slot — audio indicator + mute on click. Hidden when tab has no audio.
    @ViewBuilder
    private var audioControl: some View {
        switch tab.audio {
        case .none: EmptyView()
        case .playing:
            Button { browser.toggleMute(tab) } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Mute Tab")
        case .muted:
            Button { browser.toggleMute(tab) } label: {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Unmute Tab")
        }
    }

    @ViewBuilder
    private var tabContextMenu: some View {
        Button("New Tab")     { browser.newTab() }
        Button("Duplicate Tab") { browser.duplicate(tab) }
        Divider()
        Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") { browser.togglePin(tab) }
        if tab.audio != .none {
            Button(tab.audio == .muted ? "Unmute Tab" : "Mute Tab") { browser.toggleMute(tab) }
        }
        Divider()
        Button("Close Tab",        role: .destructive) { browser.close(tab: tab) }
        Button("Close Other Tabs", role: .destructive) { browser.closeOthers(keeping: tab) }
    }
}

/// Pinned tab — narrow icon-only cell at the leading edge of the strip.
private struct PinnedTabCell: View {
    let tab: Tab
    let tabMorph: Namespace.ID
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        Button {
            browser.select(tab: tab)
        } label: {
            tab.favicon.view(size: 14)
        }
        .buttonStyle(.borderless)
        .frame(width: 36, height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tab.id == browser.selectedTabID ? Color.primary.opacity(0.08) : Color.clear)
                .padding(.vertical, 3)
        )
        .matchedGeometryEffect(id: tab.id, in: tabMorph, isSource: !browser.showTabs)
        .help(tab.title)
        .contextMenu {
            Button("Unpin Tab") { browser.togglePin(tab) }
            Divider()
            Button("Close Tab", role: .destructive) { browser.close(tab: tab) }
        }
    }
}
