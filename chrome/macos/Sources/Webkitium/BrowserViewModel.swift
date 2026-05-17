import SwiftUI
import Observation
@preconcurrency import WebKit

/// Central observable state for the browser window. One source of truth (mirrors the
/// `BrowserPageViewModel` pattern from Apple's BrowserExample sample).
@MainActor
@Observable
final class BrowserViewModel {

    // MARK: - Tabs

    // Seed tabs are assigned tabGroupIDs in init() once the group catalog UUIDs are
    // available — see init() for the mapping.
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
        Tab(title: "GitHub — Swift Sample",
            url: "https://github.com/swift/sample",
            favicon: .generic(symbol: "chevron.left.forwardslash.chevron.right")),
        Tab(title: "Wikipedia — Liquid Glass",
            url: "https://en.wikipedia.org/wiki/Liquid_Glass",
            favicon: .generic(symbol: "w.circle.fill")),
    ]
    var selectedTabID: UUID?
    var sidebarSelection: SidebarSelection?

    /// Tabs visible in the sidebar/strip given the current Tab Group filter. Pinned tabs
    /// always appear (Safari treats pinning as global across groups); the rest filter on
    /// `tabGroupID == currentTabGroupID`. When no group is selected, all tabs show.
    var visibleTabs: [Tab] {
        guard let groupID = currentTabGroupID else { return tabs }
        return tabs.filter { $0.isPinned || $0.tabGroupID == groupID }
    }

    // Toolbar / URL field — all derived from the selected tab so they stay in sync as
    // the WebView host pushes core-state updates.
    var urlText: String = ""
    var canGoBack: Bool { selectedTab?.canGoBack ?? false }
    var canGoForward: Bool { selectedTab?.canGoForward ?? false }
    var isLoading: Bool { selectedTab?.isLoading ?? false }
    var loadProgress: Double { selectedTab?.loadProgress ?? 0 }
    var hasReaderMode: Bool { selectedTab?.hasReaderMode ?? false }

    // URL bar dropdown — `urlSuggestions` is observed state refreshed by the
    // `SuggestionProvider` whenever `urlText` changes.
    var urlFieldFocused: Bool = false
    var urlSuggestions: [URLSuggestion] = []
    private var suggestionRefreshTask: Task<Void, Never>?

    /// Matches `ng::TabStripMode` from the C++ core. Today the chrome only renders
    /// `.horizontal`; the value is propagated so the WebKitium FFI can drive it.
    enum TabStripMode: Hashable { case horizontal, vertical }
    var tabStripMode: TabStripMode = .horizontal

    /// Drives `NavigationSplitView.columnVisibility`. The sidebar's hide-sidebar icon
    /// toggles this between `.all` (sidebar shown) and `.detailOnly` (sidebar hidden).
    var sidebarVisibility: NavigationSplitViewVisibility = .all

    // Tab overview
    var showTabs: Bool = false
    var overviewSearch: String = ""

    // Extensions popover
    var showExtensionsPopover: Bool = false

    // Find on page
    var findBarOpen: Bool = false
    var findText: String = ""
    var findMode: FindMode = .beginsWith
    var findMatchCount: Int = 0
    var findCurrentIndex: Int = 0

    // Downloads
    var showDownloadsPopover: Bool = false
    var downloads: [DownloadItem] = DownloadsCatalog.recent

    // Profiles
    var profiles: [BrowserProfile] = ProfileCatalog.all
    var currentProfileID: UUID
    var showProfilePicker: Bool = false

    // Site settings
    var showSiteSettingsSheet: Bool = false
    var sitePermissions: [SitePermission] = SitePermissionCatalog.defaults

    // History
    var showHistorySheet: Bool = false
    var history: [HistoryEntry] = HistoryCatalog.recent

    // Bookmarks
    var showBookmarksSheet: Bool = false
    var showAddBookmarkSheet: Bool = false
    var bookmarkFolders: [BookmarkFolder] = BookmarksCatalog.folders

    /// Append a bookmark to the chosen folder. Writes through `BookmarkStore` and
    /// refreshes the cached snapshot.
    /// Snapshot the current tab list to the persistent store. Cheap enough
    /// to call after every meaningful mutation (open / close / navigate /
    /// reorder). Private windows are skipped — their tabs live in memory
    /// only.
    func persistTabs() {
        guard !isPrivate, let store = openTabsStore, windowID > 0 else { return }
        let activeID = selectedTabID
        let snapshot = tabs.enumerated().map { idx, tab in
            PersistedTab(windowID: windowID,
                          sortIndex: idx,
                          url: tab.url,
                          title: tab.title,
                          groupID: 0,                // Tab Group sync = later
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
            // Index in system-wide Spotlight so the user can find the
            // bookmark from the menu bar. Private windows skip.
            if !isPrivate {
                CoreSpotlightIndexer.shared.indexBookmark(title: title, url: url)
            }
        }
    }

    // Reader Mode
    var readerModeOn: Bool = false
    var readerFontSize: Double = 17
    var readerTheme: ReaderTheme = .white
    enum ReaderTheme: Hashable { case white, sepia, dark, black }

    // Translation
    var showTranslationPopover: Bool = false
    var translationFrom: TranslationLanguage = .english
    var translationTo: TranslationLanguage = .spanish
    var translationAuto: Bool = false

    // Zoom
    var zoomLevel: Double = 1.0          // 1.0 = 100%
    var showZoomHUD: Bool = false
    private var zoomHUDDismissTask: Task<Void, Never>?

    // Private Browsing
    var isPrivate: Bool = false

    // Hover URL status bar
    var hoveredLink: String?

    // Page Settings (aA) menu
    var showPageSettingsMenu: Bool = false

    // Tab Groups
    var tabGroups: [TabGroup] = TabGroupCatalog.all
    var currentTabGroupID: UUID?

    // Web Inspector
    var showInspector: Bool = false
    var inspectorPane: InspectorPane = .elements
    enum InspectorPane: String, CaseIterable, Identifiable {
        case elements = "Elements"
        case console  = "Console"
        case network  = "Network"
        case storage  = "Storage"
        case sources  = "Sources"
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

    // Add to Dock
    var showAddToDockPopover: Bool = false

    // Welcome / About
    var showWelcomePanel: Bool = false

    // Sync Pairing
    var showSyncPairing: Bool = false
    var pairedSyncDevices: [SyncDevice] = SyncCatalog.paired

    // Passkeys
    var savedPasskeys: [SavedPasskey] = PasskeyCatalog.all

    // MARK: - Providers (FFI seam)
    //
    // The chrome reaches the cross-platform browser core through these provider
    // protocols. Today they're all `Mock…` actors backed by the static catalogs; once
    // WebKitium's `*BridgeC` modules are imported, the real impls drop in here without
    // any view-code changes.

    let suggestionProvider: any SuggestionProvider
    let historyStore:       any HistoryStore
    let bookmarkStore:      any BookmarkStore
    let passkeyStore:       any PasskeyStore
    let syncDeviceStore:    any SyncDeviceStore

    /// FFI-backed stores that don't have a `protocol` seam yet — wired
    /// directly. All optional so previews / tests work without native code.
    var tabGroupStore: FFITabGroupStore?
    let openTabsStore: FFIOpenTabsStore?
    var downloadsManager: FFIDownloadsManager?

    /// Per-window stable identifier used as the key for persisted open-tab
    /// rows. Generated once per `BrowserWindowHost` and threaded through.
    var windowID: Int64 = 0

    /// Installed extensions (lifted from per-view local state so toggle
    /// from any surface — popover, manage view, toolbar — propagates).
    var installedExtensions: [BrowserExtension] = ExtensionCatalog.installed

    /// Live handles to the four C-ABI bridges (extensions / sync / webauthn / color).
    /// Optional so the model can still be constructed for previews/tests without
    /// touching native code. Production code (`WebkitiumApp`) always passes one in.
    let services: BrowserServices?

    /// One `TabWebView` (wrapping a `WKWebView`) per tab, lazily created on first
    /// access. Lives for the tab's lifetime so navigation history survives tab
    /// switching. Pruned in `close(tab:)`.
    private var webViews: [UUID: TabWebView] = [:]

    /// One-at-a-time pre-warmed `WKWebView`. Cold-starting WebContent process is
    /// ~150-300ms on M-series; pre-warming hides that latency on Cmd+T / new-tab.
    /// We keep exactly **one** spare ready — never a pool — to bound memory cost.
    /// Same isolation guarantees as the regular tab pool: private windows pre-warm
    /// with `.nonPersistent()` from the start.
    private var prewarmedWebView: WKWebView?

    /// Lazily create-or-fetch the webview for a tab. If a pre-warmed instance is
    /// available, it's consumed and a fresh one is queued to replace it.
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
        // If the tab carries a seed URL, navigate the just-claimed webview to it.
        // Without this, the seed tab list ("Apple", "Hacker News", …) would render
        // as a row of about:blank pages until the user types something.
        if let tab = tabs.first(where: { $0.id == tabID }),
           !tab.url.isEmpty, tab.url != "about:blank" {
            fresh.load(tab.url)
        }
        return fresh
    }

    /// Spawn the next pre-warmed `WKWebView` if the slot is empty. Loads
    /// `about:blank` so the WebContent process actually starts up (WKWebView's
    /// process spawn is lazy until first load).
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
         services:          BrowserServices?       = nil,
         suggestionProvider: any SuggestionProvider = MockSuggestionProvider.shared,
         historyStore:       any HistoryStore       = MockHistoryStore.shared,
         bookmarkStore:      any BookmarkStore      = MockBookmarkStore.shared,
         passkeyStore:       any PasskeyStore       = MockPasskeyStore.shared,
         syncDeviceStore:    any SyncDeviceStore    = MockSyncDeviceStore.shared,
         tabGroupStore:     FFITabGroupStore? = nil,
         openTabsStore:     FFIOpenTabsStore? = nil,
         windowID:          Int64 = 0) {
        // `currentProfileID` must be initialized BEFORE any property-access referencing
        // `self` (e.g. `tabs`), per Swift's strict init rules with @Observable.
        currentProfileID = ProfileCatalog.all[0].id
        self.isPrivate = isPrivate
        self.services           = services
        self.suggestionProvider = suggestionProvider
        self.historyStore       = historyStore
        self.bookmarkStore      = bookmarkStore
        self.passkeyStore       = passkeyStore
        self.syncDeviceStore    = syncDeviceStore
        self.tabGroupStore      = tabGroupStore
        self.openTabsStore      = openTabsStore
        self.windowID           = windowID

        // Restore persisted tabs after init completes. The `Task` defers
        // until after `self` is fully constructed (we read `tabs` inside).
        if !isPrivate, let store = openTabsStore, windowID > 0 {
            Task { @MainActor [weak self, store, windowID] in
                let persisted = await store.load(windowID: windowID)
                guard let self, !persisted.isEmpty else { return }
                self.tabs = persisted.map { p in
                    Tab(title: p.title.isEmpty ? p.url : p.title,
                        url: p.url,
                        favicon: BrandFavicon.match(for: p.title))
                }
                // Crucial: re-bind `selectedTabID` to the new UUID for the
                // active restored tab. Without this it still points at the
                // seeded tab UUIDs (gone after the reassignment above) and
                // `selectedTab` returns nil, leaving every URL-derived view
                // (lock indicator, URL bar, go-back state) stuck on empty.
                if let activeIdx = persisted.firstIndex(where: { $0.isActive }) {
                    self.selectedTabID    = self.tabs[activeIdx].id
                    self.sidebarSelection = .tab(self.tabs[activeIdx].id)
                } else if let firstIdx = self.tabs.indices.first {
                    self.selectedTabID    = self.tabs[firstIdx].id
                    self.sidebarSelection = .tab(self.tabs[firstIdx].id)
                }
                // Actively navigate each restored tab's WebView so KVO
                // re-pushes the URL/title/loading state into the model.
                // Without this the WebViews are blank shells until clicked.
                for tab in self.tabs where !tab.url.isEmpty {
                    self.wrapper(for: tab.id).load(tab.url)
                }
                // Sensible fallback: if the active restored tab has no URL
                // (fresh install, or first-run before any navigation), seed
                // it to a known https page so the chrome has something
                // meaningful to display.
                if (self.selectedTab?.url ?? "").isEmpty,
                   let tab = self.selectedTab {
                    self.wrapper(for: tab.id).load("https://en.wikipedia.org")
                }
            }
        }
        // Assign tabs to groups now that we can reference the group catalog UUIDs.
        // tabs 0..1 → Today, tab 2 → Reading, tabs 3..5 → ungrouped (visible in "All").
        tabs[0].tabGroupID = tabGroups[0].id     // Today    — Apple
        tabs[0].canGoBack  = true                 // seeded so the toolbar chevrons read live
        tabs[1].tabGroupID = tabGroups[0].id     // Today    — Google
        tabs[1].canGoBack  = true
        tabs[2].tabGroupID = tabGroups[1].id     // Reading  — Hacker News
        tabs[3].tabGroupID = tabGroups[1].id     // Reading  — Swift.org
        // Wikipedia stays ungrouped.
        // Private windows start with a clean slate — no tab history, fresh new-tab page.
        if isPrivate {
            tabs = [Tab(title: "New Tab",
                         url: "about:blank",
                         favicon: .generic(symbol: "globe"))]
            // Private windows ignore the regular catalogs — start clean.
        }
        selectedTabID = tabs.last?.id
        if let id = selectedTabID { sidebarSelection = .tab(id) }
        Task { await self.refreshFromStores() }
        // Spawn the first pre-warmed `WKWebView` so the first Cmd+T (or the first
        // navigation away from `about:blank`) doesn't pay WebContent cold-start cost.
        prewarmIfNeeded()
    }

    /// Re-fetch history/bookmarks/passkeys/devices snapshots from the providers. Called
    /// at init and after any mutation that may have synced from a peer device.
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

    /// Debounced refresh of the URL-bar suggestions, routed through `SuggestionProvider`.
    /// Cancels any in-flight refresh so only the latest query wins.
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

    // MARK: - Tab mutations

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
        // New tabs inherit the currently-selected Tab Group (if any), matching Safari's
        // "+" behavior when you're already inside a group.
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
        // New ID for the duplicate — the rest of the metadata copies forward.
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

    // MARK: - Navigation
    //
    // All four routes dispatch to the per-tab `TabWebView` wrapper. KVO on the
    // underlying `WKWebView` flows state back into the matching `Tab` struct
    // (isLoading, loadProgress, canGoBack, canGoForward, title, url) — the chrome
    // reads those for UI binding.

    /// User submitted text in the URL bar. The wrapper normalizes input (URL vs.
    /// search query) and kicks off a `WKWebView.load(...)`.
    func navigateActive(to text: String) {
        guard let tab = selectedTab else { return }
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

    // MARK: - Find on page

    func openFindBar() {
        withAnimation(.smooth) { findBarOpen = true }
    }
    func closeFindBar() {
        withAnimation(.smooth) { findBarOpen = false }
        findText = ""
    }
    func recomputeFindMatches() {
        // No real page to search; mock the count off the query length.
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

    // MARK: - Tab Groups

    /// Switch (or unset) the active Tab Group. If the currently-selected tab isn't in the
    /// new visible set, jump selection to the first visible tab so the URL field, content
    /// pane, and selected highlight stay coherent.
    func selectTabGroup(_ groupID: UUID?) {
        currentTabGroupID = (currentTabGroupID == groupID) ? nil : groupID
        if let sel = selectedTab,
           !visibleTabs.contains(where: { $0.id == sel.id }),
           let first = visibleTabs.first {
            selectedTabID = first.id
            sidebarSelection = .tab(first.id)
        }
    }

    // MARK: - Zoom

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
