import SwiftUI

/// Compact horizontal Tab Groups strip under the sidebar header — color dot + name pill
/// per group with hover/selected styling. A trailing "+" adds a new group. Matches Safari's
/// segmented tab-group chip row in the sidebar.
struct TabGroupsBar: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // "All" pill — clears the filter; Safari's analog is unselecting the
                // active group title in the sidebar header.
                AllTabsChip(selected: browser.currentTabGroupID == nil)
                    .onTapGesture { browser.selectTabGroup(nil) }
                ForEach(browser.tabGroups) { group in
                    TabGroupChip(group: group,
                                  selected: group.id == browser.currentTabGroupID)
                        .onTapGesture { browser.selectTabGroup(group.id) }
                }
                Button {
                    let g = TabGroup(name: "New Group",
                                      tintHex: 0x6b9bd1,
                                      symbol: "circle.grid.2x2")
                    browser.tabGroups.append(g)
                    browser.selectTabGroup(g.id)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help("New Tab Group")
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
    }
}

private struct AllTabsChip: View {
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 9, weight: .semibold))
            Text("All")
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .foregroundStyle(selected ? .white : .primary)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? Color.accentColor :
                      (hovering ? Color.primary.opacity(0.08) : .clear))
        )
        .onHover { hovering = $0 }
    }
}

private struct TabGroupChip: View {
    let group: TabGroup
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(group.color)
                .frame(width: 8, height: 8)
            Text(group.name)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 22)
        .foregroundStyle(selected ? .white : .primary)
        .background(
            Capsule(style: .continuous)
                .fill(selected ? Color.accentColor :
                      (hovering ? Color.primary.opacity(0.08) : .clear))
        )
        .onHover { hovering = $0 }
        .help(group.name)
    }
}
