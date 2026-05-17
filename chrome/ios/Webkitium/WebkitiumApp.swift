import SwiftUI

@main
struct WebkitiumApp: App {
    @State private var browser: BrowserViewModel

    init() {
        let dbPath = ProfileDB.path()
        let provider = FFISuggestionProvider(dbPath: dbPath)
        let history  = FFIHistoryStore(dbPath: dbPath)
        let bookmark = FFIBookmarkStore(dbPath: dbPath)
        let openTabs = FFIOpenTabsStore(dbPath: dbPath)
        let tabGroup = FFITabGroupStore(dbPath: dbPath)
        let wid = Self.nextWindowID()
        let vm = BrowserViewModel(
            suggestionProvider: provider,
            historyStore: history,
            bookmarkStore: bookmark,
            tabGroupStore: tabGroup,
            openTabsStore: openTabs,
            windowID: wid)
        let mgr = FFIDownloadsManager(dbPath: dbPath, browser: vm)
        vm.downloadsManager = mgr
        _browser = State(initialValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            iOSRootView()
                .environment(browser)
        }
    }

    private static func nextWindowID() -> Int64 {
        let key = "Webkitium.NextWindowID"
        let next = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(next, forKey: key)
        return Int64(next)
    }
}

/// Profile DB location for iOS — Documents directory so files survive
/// reinstall-free upgrades and are visible from the Files app for debug.
enum ProfileDB {
    static func path() -> String? {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory,
                                  in: .userDomainMask).first else { return nil }
        let dir = docs.appendingPathComponent("Webkitium", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("suggestions.db").path
    }
}
