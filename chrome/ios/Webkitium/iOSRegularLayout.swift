import SwiftUI
import WebkitiumSuggestionsC

/// iPad / regular-width-class layout. Mirrors the macOS `RootView` —
/// `NavigationSplitView` with sidebar + tab strip + top URL toolbar +
/// `WKWebView`. Compact-width devices (iPhone portrait, Split View) use
/// `iOSRootView`'s compact branch instead.
struct iOSRootViewRegular: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var b = browser

        NavigationSplitView(columnVisibility: $b.sidebarVisibility) {
            iPadSidebar()
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(spacing: 0) {
                iPadTabStrip()
                if browser.findBarOpen {
                    iPadFindBar()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Divider()
                ContentRouter()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .toolbar { iPadTopToolbar() }
            .animation(.smooth(duration: 0.22), value: browser.findBarOpen)
            .sheet(isPresented: $b.showSettings)        { iOSSettingsView() }
            .sheet(isPresented: $b.showBookmarksSheet)  { iPadPlaceholderSheet(title: "Bookmarks", symbol: "book.closed") }
            .sheet(isPresented: $b.showHistorySheet)    { iPadPlaceholderSheet(title: "History",   symbol: "clock.arrow.circlepath") }
            .sheet(isPresented: $b.showDownloadsPopover){ iPadPlaceholderSheet(title: "Downloads", symbol: "arrow.down.circle") }
        }
        .navigationSplitViewStyle(.prominentDetail)
    }
}

// MARK: - Sidebar (bookmarks / reading list / tabs list)

private struct iPadSidebar: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var b = browser
        List(selection: $b.sidebarSelection) {
            Section("Library") {
                Label("Bookmarks", systemImage: "book.closed")
                    .tag(SidebarSelection.leaf(.bookmarks))
                Label("Reading List", systemImage: "eyeglasses")
                    .tag(SidebarSelection.leaf(.readingList))
                Label("Shared with You", systemImage: "person.2")
                    .tag(SidebarSelection.leaf(.sharedWithYou))
            }
            Section("Open Tabs") {
                ForEach(browser.visibleTabs) { tab in
                    Label(tab.title.isEmpty ? "New Tab" : tab.title,
                          systemImage: tab.isLoading ? "circle.dotted" : "doc")
                        .lineLimit(1)
                        .tag(SidebarSelection.tab(tab.id))
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Webkitium")
    }
}

// MARK: - Tab strip (above WebView, in detail column)

private struct iPadTabStrip: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(browser.visibleTabs) { tab in
                    iPadTabChip(tab: tab,
                                isSelected: tab.id == browser.selectedTabID)
                }
                Button(action: { browser.newTab() }) {
                    Image(systemName: "plus")
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("New Tab")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(height: 38)
        .background(.thinMaterial)
    }
}

private struct iPadTabChip: View {
    @Environment(BrowserViewModel.self) private var browser
    let tab: Tab
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if tab.isLoading {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
            }
            Text(tab.title.isEmpty ? "New Tab" : tab.title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .frame(maxWidth: 140)
            Button(action: { browser.close(tab: tab) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Close Tab: \(tab.title)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { browser.sidebarSelection = .tab(tab.id) }
    }
}

// MARK: - Top toolbar (back/forward, URL pill, action buttons)

private struct iPadTopToolbar: ToolbarContent {
    @Environment(BrowserViewModel.self) private var browser

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button(action: { browser.goBack() }) {
                Image(systemName: "chevron.left")
            }
            .disabled(!browser.canGoBack)
        }
        ToolbarItem(placement: .navigation) {
            Button(action: { browser.goForward() }) {
                Image(systemName: "chevron.right")
            }
            .disabled(!browser.canGoForward)
        }
        ToolbarItem(placement: .principal) {
            iPadURLField()
                .frame(minWidth: 260, idealWidth: 460, maxWidth: 720)
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { browser.findBarOpen.toggle() }) {
                Image(systemName: "magnifyingglass")
            }
            .accessibilityLabel("Find in Page")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { browser.showBookmarksSheet = true }) {
                Image(systemName: "book.closed")
            }
            .accessibilityLabel("Bookmarks")
        }
        ToolbarItem(placement: .primaryAction) {
            Button(action: { browser.showSettings = true }) {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("More")
        }
    }
}

private struct iPadURLField: View {
    @Environment(BrowserViewModel.self) private var browser
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var b = browser
        HStack(spacing: 8) {
            let isSecure = browser.selectedTab?.url.hasPrefix("https://") == true
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.23, green: 0.51, blue: 0.96))
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.75), radius: 5)
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.45), radius: 10)
                .opacity(isSecure ? 1.0 : 0.0)
                .animation(.smooth(duration: 0.25), value: isSecure)
            TextField("Search or enter website", text: $b.urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .focused($focused)
                .submitLabel(.go)
                .onSubmit { commit() }
            if !browser.urlText.isEmpty {
                Button(action: { browser.urlText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 13))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemFill))
        )
        .accessibilityLabel("Address bar")
    }

    private func commit() {
        guard let tab = browser.selectedTab else { return }
        if let url = TabWebView.normalize(browser.urlText) {
            browser.webView(for: tab).load(URLRequest(url: url))
        }
    }
}

// MARK: - Find bar (top of detail, regular layout)

private struct iPadFindBar: View {
    @Environment(BrowserViewModel.self) private var browser
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var b = browser
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find on Page", text: $b.findText)
                .textInputAutocapitalization(.never)
                .focused($fieldFocused)
                .onChange(of: browser.findText) { _, _ in browser.recomputeFindMatches() }
            if browser.findMatchCount > 0 {
                Text("\(browser.findCurrentIndex) of \(browser.findMatchCount)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Button(action: { browser.previousFindMatch() }) { Image(systemName: "chevron.up") }
                .disabled(browser.findMatchCount == 0)
            Button(action: { browser.nextFindMatch() })     { Image(systemName: "chevron.down") }
                .disabled(browser.findMatchCount == 0)
            Button("Done") { browser.closeFindBar() }
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .onAppear { fieldFocused = true }
    }
}

// MARK: - Content router (mirrors macOS pattern)

private struct ContentRouter: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        switch browser.sidebarSelection {
        case .leaf(.bookmarks):     iPadBookmarksLeafPane()
        case .leaf(.readingList):   iPadReadingListLeafPane()
        case .leaf(.sharedWithYou): iPadPlaceholderPane(title: "Shared with You", symbol: "person.2")
        case .tab, .none:
            if let tab = browser.selectedTab {
                WebContentArea(webView: browser.webView(for: tab))
            } else {
                iPadPlaceholderPane(title: "New Tab", symbol: "globe")
            }
        }
    }
}

private struct iPadPlaceholderPane: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.title2.weight(.semibold))
            Text("Content for \(title) will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct iPadPlaceholderSheet: View {
    let title: String
    let symbol: String
    var body: some View {
        NavigationStack {
            iPadPlaceholderPane(title: title, symbol: symbol)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Bookmarks / Reading List panes (FFI-backed, ported from macOS)

private struct iPadLeafRow: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: String
}

struct iPadBookmarksLeafPane: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var rows: [iPadLeafRow] = []

    var body: some View {
        iPadLeafList(title: "Bookmarks", symbol: "book.closed", rows: rows)
            .task { rows = await iPadBookmarksFetcher.flatBookmarks(isPrivate: browser.isPrivate) }
    }
}

struct iPadReadingListLeafPane: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var rows: [iPadLeafRow] = []

    var body: some View {
        iPadLeafList(title: "Reading List", symbol: "eyeglasses", rows: rows)
            .task { rows = await iPadBookmarksFetcher.readingList(isPrivate: browser.isPrivate) }
    }
}

private struct iPadLeafList: View {
    let title: String
    let symbol: String
    let rows: [iPadLeafRow]
    var body: some View {
        if rows.isEmpty {
            iPadPlaceholderPane(title: title, symbol: symbol)
        } else {
            List(rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                    Text(row.url).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }
}

private enum iPadBookmarksFetcher {
    static func flatBookmarks(isPrivate: Bool) async -> [iPadLeafRow] {
        await read(isPrivate: isPrivate, kind: .bookmarks)
    }
    static func readingList(isPrivate: Bool) async -> [iPadLeafRow] {
        await read(isPrivate: isPrivate, kind: .readingList)
    }

    private enum Kind { case bookmarks, readingList }

    private static func read(isPrivate: Bool, kind: Kind) async -> [iPadLeafRow] {
        guard !isPrivate, let cPath = ProfileDB.path() else { return [] }
        guard let h = cPath.withCString({ wk_suggestions_open($0) }) else { return [] }
        defer { wk_suggestions_close(h) }
        var list = WkSuggestionResults(rows: nil, count: 0, _opaque: nil)
        let ok: Int32 = {
            switch kind {
            case .bookmarks:   return wk_suggestions_bookmarks_flat(h, 200, &list)
            case .readingList: return wk_suggestions_reading_list(h, 200, &list)
            }
        }()
        guard ok == 1 else { return [] }
        defer { wk_suggestions_release_results(&list) }
        return (0..<Int(list.count)).map { i in
            let r = list.rows![i]
            return iPadLeafRow(
                title: r.title.map(String.init(cString:)) ?? "",
                url:   r.subtitle.map(String.init(cString:)) ?? "")
        }
    }
}
