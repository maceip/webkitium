import SwiftUI

/// The "exploded view" — grid of thumbnail cards shown when the user clicks the overview
/// toolbar button (or hits Cmd+Shift+\\). Uses `matchedGeometryEffect` paired with the tab
/// strip so SwiftUI handles the morph from strip cell → full-screen thumbnail card and
/// back. This is the same pattern Apple's BrowserExample sample uses (WWDC25).
struct TabOverviewView: View {
    @Environment(BrowserViewModel.self) private var browser
    let tabMorph: Namespace.ID

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 360), spacing: 20)
    ]

    var body: some View {
        @Bindable var browserBinding = browser
        ZStack {
            Color.black.opacity(0.22).ignoresSafeArea()

            VStack(spacing: 0) {
                searchField
                    .padding(.top, 12)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(browser.tabsForOverview) { tab in
                        ThumbnailCard(tab: tab, tabMorph: tabMorph)
                            .onTapGesture {
                                withAnimation(.smooth) {
                                    browser.select(tab: tab)
                                    browser.showTabs = false
                                }
                            }
                    }

                    NewTabCard()
                        .onTapGesture {
                            withAnimation(.smooth) {
                                browser.newTab()
                                browser.showTabs = false
                            }
                        }
                }
                    .padding(28)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.smooth) { browser.showTabs = false }
                }
            }
        }
    }

    private var searchField: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search Tabs", text: $browserBinding.overviewSearch)
                .textFieldStyle(.plain)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 26)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

private struct ThumbnailCard: View {
    let tab: Tab
    let tabMorph: Namespace.ID
    @Environment(BrowserViewModel.self) private var browser
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.smooth) { browser.close(tab: tab) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .opacity(hovering ? 1 : 0)
                .frame(width: 12, height: 12)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star")
                        .font(.system(size: 9))
                    Text(tab.title)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .foregroundStyle(.primary)

                Spacer()
                Spacer().frame(width: 12)
            }
            .padding(.horizontal, 6)
            .frame(height: 22)

            ThumbnailPreview(title: tab.title)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(hovering ? Color.primary.opacity(0.35) : Color.primary.opacity(0.10),
                        lineWidth: hovering ? 2 : 1)
        )
        .matchedGeometryEffect(id: tab.id, in: tabMorph, isSource: browser.showTabs)
        .onHover { hovering = $0 }
    }
}

private struct ThumbnailPreview: View {
    let title: String

    var body: some View {
        // Miniature Start Page snapshot — a couple of "favicon rows" and a card silhouette.
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<8, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(MockFavicon.palette[i % MockFavicon.palette.count])
                        .frame(width: 18, height: 18)
                }
            }
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.thinMaterial)
                .frame(height: 80)
                .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}

private enum MockFavicon {
    static let palette: [Color] = [
        .white, .blue, .yellow, .blue, .blue, .white, .blue, .black
    ]
}

private struct NewTabCard: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.regularMaterial)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
        }
        .frame(height: 182)
    }
}
