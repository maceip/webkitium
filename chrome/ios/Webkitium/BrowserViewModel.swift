import SwiftUI
import Observation
@preconcurrency import WebKit

/// iOS variant of the macOS BrowserViewModel. Strips out:
/// - `NavigationSplitView.columnVisibility` (no sidebar on iPhone)
/// - desktop-only menu state surfaces (Web Inspector etc — left as flags for parity)
/// - macOS-specific hover and zoom HUD machinery (kept but inert)
///
/// Everything else is identical to keep one mental model across platforms.
@MainActor
@Observable
final class BrowserViewModel {

    // MARK: - Tabs

    var tabs: [Tab] = [
        Tab(title: "Apple",
            url: "https://www.apple.com",
            favicon: .apple,
            hasReaderMode: true),
        Tab(title: "android* - Google Search",
            url: "https://www.google.com/search?q=android",
            isLoading: true, loadProgress: 0.62,
            favicon: .google, audio: .playing),
        Tab(title: "Hacker News",
            url: "https://news.ycombinator.com",
            favicon: .generic(symbol: "n.square.fill")),
        Tab(title: "Swift.org",
            url: "https://www.swift.org",
            favicon: .generic(symbol: "swift")),
    ]
    var selectedTabID: UUID?
    var sidebarSelection: SidebarSelection?

    var visibleTabs: [Tab] {
        guard let groupID = currentTabGroupID else { return tabs }
        return tabs.filter { $0.isPinned || $0.tabGroupID == groupID }
    }

    var urlText: String = ""
    var canGoBack: Bool { selectedTab?.canGoBack ?? false }
    var canGoForward: Bool { selectedTab?.canGoForward ?? false }
    var isLoading: Bool { selectedTab?.isLoading ?? false }
    var loadProgress: Double { selectedTab?.loadProgress ?? 0 }
    var hasReaderMode: Bool { selectedTab?.hasReaderMode ?? false }

    var urlFieldFocused: Bool = false
    var urlSuggestions: [URLSuggestion] = []
    private var suggestionRefreshTask: Task<Void, Never>?

    // iOS: tab strip mode is moot — there's no strip. Kept for FFI symmetry.
    enum TabStripMode: Hashable { case horizontal, vertical }
    var tabStripMode: TabStripMode = .horizontal

    var showTabs: Bool = false
    var overviewSearch: String = ""

    var showExtensionsPopover: Bool = false

    var findBarOpen: Bool = false
    var findText: String = ""
    var findMode: FindMode = .beginsWith
    var findMatchCount: Int = 0
    var findCurrentIndex: Int = 0

    var showDownloadsPopover: Bool = false
    var downloads: [DownloadItem] = DownloadsCatalog.recent

    var profiles: [BrowserProfile] = ProfileCatalog.all
    var currentProfileID: UUID
    var showProfilePicker: Bool = false

    var showSiteSettingsSheet: Bool = false
    var sitePermissions: [SitePermission] = SitePermissionCatalog.defaults

    var showHistorySheet: Bool = false
    var history: [HistoryEntry] = HistoryCatalog.recent

    var showBookmarksSheet: Bool = false
    var showAddBookmarkSheet: Bool = false
    var bookmarkFolders: [BookmarkFolder] = BookmarksCatalog.folders

    func persistTabs() {
        guard !isPrivate, let store = openTabsStore, windowID > 0 else { return }
        let activeID = selectedTabID
        let snapshot = tabs.enumerated().map { idx, tab in
            PersistedTab(windowID: windowID,
                          sortIndex: idx,
                          url: tab.url,
                          title: tab.title,
                          groupID: 0,
                          isPinned: tab.isPinned,
                          isActive: tab.id == activeID)
        }
        let wid = windowID
        Task { await store.save(windowID: wid, tabs: snapshot) }
    }

    func addBookmark(title: String, url: String, folder: BookmarkFolder) {
        let entry = BookmarkEntry(title: title, url: url,
                                    favicon: selectedTab?.favicon ?? .generic(symbol: "globe"))
        let store = bookmarkStore
        let provider = suggestionProvider
        let isPrivate = self.isPrivate
        Task { @MainActor in
            await store.addBookmark(entry, to: folder.id)
            self.bookmarkFolders = await store.folders()
            await provider.setBookmarked(url: url, isBookmarked: true)
            if !isPrivate {
                CoreSpotlightIndexer.shared.indexBookmark(title: title, url: url)
            }
        }
    }

    var readerModeOn: Bool = false
    var readerFontSize: Double = 17
    var readerTheme: ReaderTheme = .white
    enum ReaderTheme: Hashable { case white, sepia, dark, black }

    var showTranslationPopover: Bool = false
    var translationFrom: TranslationLanguage = .english
    var translationTo: TranslationLanguage = .spanish
    var translationAuto: Bool = false

    var zoomLevel: Double = 1.0
    var showZoomHUD: Bool = false
    private var zoomHUDDismissTask: Task<Void, Never>?

    var isPrivate: Bool = false

    /// Driven by the regular-width layout (iPad) — same semantics as the
    /// macOS shell. The compact layout ignores it (no sidebar).
    var sidebarVisibility: NavigationSplitViewVisibility = .all

    var hoveredLink: String?  // unused on iOS but kept for cross-platform parity

    var showPageSettingsMenu: Bool = false
    var showSettings: Bool = false

    var tabGroups: [TabGroup] = TabGroupCatalog.all
    var currentTabGroupID: UUID?

    var showInspector: Bool = false
    var inspectorPane: InspectorPane = .elements
    enum InspectorPane: String, CaseIterable, Identifiable {
        case elements = "Elements", console = "Console", network = "Network", storage = "Storage", sources = "Sources"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .elements: return "chevron.left.forwardslash.chevron.right"
            case .console:  return "terminal"
            case .network:  return "network"
            case .storage:  return "internaldrive"
            case .sources:  return "doc.text"
            }
        }
    }

    var showAddToDockPopover: Bool = false
    var showWelcomePanel: Bool = false
    var showSyncPairing: Bool = false
    var pairedSyncDevices: [SyncDevice] = SyncCatalog.paired
    var savedPasskeys: [SavedPasskey] = PasskeyCatalog.all

    let suggestionProvider: any SuggestionProvider
    let historyStore:       any HistoryStore
    let bookmarkStore:      any BookmarkStore
    let passkeyStore:       any PasskeyStore
    let syncDeviceStore:    any SyncDeviceStore

    var tabGroupStore: FFITabGroupStore?
    let openTabsStore: FFIOpenTabsStore?
    var downloadsManager: FFIDownloadsManager?

    var windowID: Int64 = 0

    var installedExtensions: [BrowserExtension] = ExtensionCatalog.installed

    private var webViews: [UUID: TabWebView] = [:]
    private var prewarmedWebView: WKWebView?

    func webView(for tab: Tab) -> WKWebView {
        wrapper(for: tab.id).webView
    }
    private func wrapper(for tabID: UUID) -> TabWebView {
        if let existing = webViews[tabID] { return existing }
        let preset = prewarmedWebView
        prewarmedWebView = nil
        let fresh = TabWebView(tabID: tabID, browser: self, presetWebView: preset)
        webViews[tabID] = fresh
        prewarmIfNeeded()
        if let tab = tabs.first(where: { $0.id == tabID }),
           !tab.url.isEmpty, tab.url != "about:blank" {
            fresh.load(tab.url)
        }
        return fresh
    }

    func prewarmIfNeeded() {
        guard prewarmedWebView == nil else { return }
        let config = WKWebViewConfiguration()
        if isPrivate { config.websiteDataStore = .nonPersistent() }
        let wv = WKWebView(frame: .zero, configuration: config)
        if let blank = URL(string: "about:blank") {
            wv.load(URLRequest(url: blank))
        }
        prewarmedWebView = wv
    }

    init(isPrivate: Bool = false,
         suggestionProvider: any SuggestionProvider = MockSuggestionProvider.shared,
         historyStore:       any HistoryStore       = MockHistoryStore.shared,
         bookmarkStore:      any BookmarkStore      = MockBookmarkStore.shared,
         passkeyStore:       any PasskeyStore       = MockPasskeyStore.shared,
         syncDeviceStore:    any SyncDeviceStore    = MockSyncDeviceStore.shared,
         tabGroupStore:     FFITabGroupStore? = nil,
         openTabsStore:     FFIOpenTabsStore? = nil,
         windowID:          Int64 = 0) {
        currentProfileID = ProfileCatalog.all[0].id
        self.isPrivate = isPrivate
        self.suggestionProvider = suggestionProvider
        self.historyStore       = historyStore
        self.bookmarkStore      = bookmarkStore
        self.passkeyStore       = passkeyStore
        self.syncDeviceStore    = syncDeviceStore
        self.tabGroupStore      = tabGroupStore
        self.openTabsStore      = openTabsStore
        self.windowID           = windowID

        // Apply seed-catalog tab-group wiring synchronously. If we end up
        // restoring persisted tabs below the array will be replaced — these
        // assignments only matter when no persistence kicks in.
        if !isPrivate {
            tabs[0].tabGroupID = tabGroups[0].id
            tabs[0].canGoBack  = true
            tabs[1].tabGroupID = tabGroups[0].id
            tabs[1].canGoBack  = true
            tabs[2].tabGroupID = tabGroups[1].id
            tabs[3].tabGroupID = tabGroups[1].id
        }
        if isPrivate {
            tabs = [Tab(title: "New Tab",
                         url: "about:blank",
                         favicon: .generic(symbol: "globe"))]
        }
        if !isPrivate, let store = openTabsStore, windowID > 0 {
            Task { @MainActor [weak self, store, windowID] in
                let persisted = await store.load(windowID: windowID)
                guard let self, !persisted.isEmpty else { return }
                // Map group_id back to UUID via the in-memory catalog. The
                // FFI rows store Int64; the chrome model uses UUIDs. Without
                // a real id map, persisted tabs land ungrouped (groupID nil)
                // — better than racing the seed-catalog assignments above.
                self.tabs = persisted.map { p in
                    Tab(title: p.title.isEmpty ? p.url : p.title,
                        url: p.url,
                        favicon: BrandFavicon.match(for: p.title))
                }
                if let idx = persisted.firstIndex(where: { $0.isActive }) {
                    self.sidebarSelection = .tab(self.tabs[idx].id)
                    self.selectedTabID = self.tabs[idx].id
                }
            }
        }
        // iOS first-cut starts on Start Page (no selected tab) so the
        // launch matches Safari iOS's behavior — fresh start, favorites
        // and privacy report visible. Tap a favorite or open a tab to
        // navigate.
        selectedTabID = nil
        Task { await self.refreshFromStores() }
        prewarmIfNeeded()
    }

    func refreshFromStores() async {
        async let h  = historyStore.recent(query: nil, limit: 200)
        async let b  = bookmarkStore.folders()
        async let pk = passkeyStore.saved()
        async let dv = syncDeviceStore.paired()
        let (hh, bb, pp, dd) = await (h, b, pk, dv)
        self.history          = hh
        self.bookmarkFolders  = bb
        self.savedPasskeys    = pp
        self.pairedSyncDevices = dd
    }

    func refreshSuggestions() {
        suggestionRefreshTask?.cancel()
        let q = urlText
        suggestionRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.suggestionProvider.suggestions(for: q)
            if !Task.isCancelled { self.urlSuggestions = result }
        }
    }

    var selectedTab: Tab? { tabs.first { $0.id == selectedTabID } }
    var currentProfile: BrowserProfile {
        profiles.first { $0.id == currentProfileID } ?? profiles[0]
    }

    var tabsForOverview: [Tab] {
        guard !overviewSearch.isEmpty else { return tabs }
        let q = overviewSearch.lowercased()
        return tabs.filter { $0.title.lowercased().contains(q) }
    }

    func select(tab: Tab) {
        selectedTabID = tab.id
        sidebarSelection = .tab(tab.id)
    }

    func close(tab: Tab) {
        tabs.removeAll { $0.id == tab.id }
        webViews.removeValue(forKey: tab.id)
        if selectedTabID == tab.id { selectedTabID = tabs.last?.id }
        persistTabs()
    }

    func newTab() {
        let t = Tab(title: "New Tab",
                    favicon: .generic(symbol: "globe"),
                    tabGroupID: currentTabGroupID)
        tabs.append(t)
        selectedTabID = t.id
        sidebarSelection = .tab(t.id)
        persistTabs()
    }

    func duplicate(_ tab: Tab) {
        guard let idx = tabs.firstIndex(of: tab) else { return }
        tabs.insert(Tab(title: tab.title,
                         url: tab.url,
                         isPinned: tab.isPinned,
                         loadProgress: 1,
                         favicon: tab.favicon,
                         hasReaderMode: tab.hasReaderMode),
                     at: idx + 1)
    }

    func togglePin(_ tab: Tab) {
        guard let idx = tabs.firstIndex(of: tab) else { return }
        tabs[idx].isPinned.toggle()
    }

    func closeOthers(keeping tab: Tab) {
        tabs.removeAll { $0.id != tab.id }
        selectedTabID = tab.id
    }

    func toggleMute(_ tab: Tab) {
        guard let idx = tabs.firstIndex(of: tab) else { return }
        switch tabs[idx].audio {
        case .none:    tabs[idx].audio = .none
        case .playing: tabs[idx].audio = .muted
        case .muted:   tabs[idx].audio = .playing
        }
    }

    func navigateActive(to text: String) {
        if selectedTab == nil { newTab() }
        guard let tab = selectedTab else { return }
        urlText = text
        if let idx = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[idx].url = text
        }
        wrapper(for: tab.id).load(text)
    }

    func reloadOrStop() {
        guard let tab = selectedTab else { return }
        let w = wrapper(for: tab.id)
        if tab.isLoading { w.stop() } else { w.reload() }
    }

    func goBack() {
        guard let tab = selectedTab, tab.canGoBack else { return }
        wrapper(for: tab.id).goBack()
    }
    func goForward() {
        guard let tab = selectedTab, tab.canGoForward else { return }
        wrapper(for: tab.id).goForward()
    }

    func openFindBar() {
        withAnimation(.smooth) { findBarOpen = true }
    }
    func closeFindBar() {
        withAnimation(.smooth) { findBarOpen = false }
        findText = ""
    }
    func recomputeFindMatches() {
        findMatchCount = findText.isEmpty ? 0 : min(findText.count * 3, 47)
        findCurrentIndex = findMatchCount > 0 ? 1 : 0
    }
    func nextFindMatch() {
        guard findMatchCount > 0 else { return }
        findCurrentIndex = findCurrentIndex >= findMatchCount ? 1 : findCurrentIndex + 1
    }
    func previousFindMatch() {
        guard findMatchCount > 0 else { return }
        findCurrentIndex = findCurrentIndex <= 1 ? findMatchCount : findCurrentIndex - 1
    }

    func selectTabGroup(_ groupID: UUID?) {
        currentTabGroupID = (currentTabGroupID == groupID) ? nil : groupID
        if let sel = selectedTab,
           !visibleTabs.contains(where: { $0.id == sel.id }),
           let first = visibleTabs.first {
            selectedTabID = first.id
            sidebarSelection = .tab(first.id)
        }
    }

    func zoomIn() {
        zoomLevel = min(3.0, (zoomLevel * 100).rounded() / 100 + 0.1)
        flashZoomHUD()
    }
    func zoomOut() {
        zoomLevel = max(0.5, (zoomLevel * 100).rounded() / 100 - 0.1)
        flashZoomHUD()
    }
    func zoomReset() {
        zoomLevel = 1.0
        flashZoomHUD()
    }
    private func flashZoomHUD() {
        showZoomHUD = true
        zoomHUDDismissTask?.cancel()
        zoomHUDDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard let self else { return }
            withAnimation(.smooth(duration: 0.18)) { self.showZoomHUD = false }
        }
    }
}
