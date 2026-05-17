import SwiftUI

@main
struct WebkitiumApp: App {
    /// Process-wide handle bag for the four C-ABI bridges in browser/. One instance for
    /// the whole app — every browser window's view model holds a reference and reads
    /// counts/state through it.
    @State private var services: BrowserServices

    /// Singleton VM used by the auxiliary windows (Settings / Sync / Passkeys). Each
    /// **browser** window gets its own VM via `BrowserWindowHost` so private windows are
    /// truly isolated from the regular one.
    @State private var sharedAuxBrowser: BrowserViewModel

    init() {
        guard let s = BrowserServices() else {
            fatalError("BrowserServices: failed to construct one of the four C bridges (extensions / sync / webauthn)")
        }
        _services = State(initialValue: s)
        _sharedAuxBrowser = State(initialValue: BrowserViewModel(services: s))
    }

    var body: some Scene {
        WindowGroup(id: "browser") {
            BrowserWindowHost(isPrivate: false, services: services)
        }
        .defaultSize(width: 1880, height: 1000)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { SafariCommands(browser: sharedAuxBrowser) }

        WindowGroup(id: "private-browser") {
            BrowserWindowHost(isPrivate: true, services: services)
        }
        .defaultSize(width: 1880, height: 1000)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))

        Window("Settings", id: "settings") {
            SettingsView(initialTarget: nil)
                .environment(sharedAuxBrowser)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 880, height: 560)

        Window("Sync Setup", id: "sync") {
            SyncPairingView()
                .environment(sharedAuxBrowser)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 560)

        Window("Passkeys", id: "passkeys") {
            PasskeyManagerView()
                .environment(sharedAuxBrowser)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 540)
    }
}

/// Hosts a single browser window with its own `BrowserViewModel`. Each instance of the
/// `WindowGroup` gets a fresh VM, so spawning a Private window via `openWindow(id:
/// "private-browser")` creates a truly isolated state container — separate tabs,
/// separate history, separate sidebar.
struct BrowserWindowHost: View {
    @State private var browser: BrowserViewModel

    init(isPrivate: Bool, services: BrowserServices) {
        // All FFI-backed stores point at the same SQLite DB per profile.
        // Regular windows persist; private windows use in-memory (empty path).
        let dbPath: String? = isPrivate ? nil : Self.defaultSuggestionsDBPath()
        let provider     = FFISuggestionProvider(dbPath: dbPath)
        let history      = FFIHistoryStore     (dbPath: dbPath)
        let bookmarks    = FFIBookmarkStore    (dbPath: dbPath)
        let tabGroups    = FFITabGroupStore    (dbPath: dbPath)
        let openTabs     = FFIOpenTabsStore    (dbPath: dbPath)
        let windowID     = Self.nextWindowID(isPrivate: isPrivate)

        let vm = BrowserViewModel(isPrivate: isPrivate,
                                   services: services,
                                   suggestionProvider: provider,
                                   historyStore: history,
                                   bookmarkStore: bookmarks,
                                   tabGroupStore: tabGroups,
                                   openTabsStore: openTabs,
                                   windowID: windowID)
        // Downloads manager retains `browser` weakly — must construct it
        // AFTER the VM exists so the back-pointer is valid.
        vm.downloadsManager = FFIDownloadsManager(dbPath: dbPath, browser: vm)
        vm.downloadsManager?.refreshSnapshot()
        _browser = State(initialValue: vm)
    }

    /// Monotonic per-launch window id. Persisted across launches via
    /// UserDefaults so reopening a window restores its tab snapshot.
    /// Private windows always get id = 0 (their open_tabs rows are written
    /// to an in-memory DB that dies with the window).
    private static func nextWindowID(isPrivate: Bool) -> Int64 {
        if isPrivate { return 0 }
        let key = "Webkitium.NextWindowID"
        let defaults = UserDefaults.standard
        let current = defaults.object(forKey: key) as? Int64 ?? 1
        defaults.set(current + 1, forKey: key)
        return current
    }

    private static func defaultSuggestionsDBPath() -> String? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory,
                                        in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("Webkitium", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("suggestions.db").path
    }

    var body: some View {
        RootView()
            .environment(browser)
            .frame(minWidth: 900, minHeight: 540)
    }
}

extension Notification.Name {
    static let openSettingsTarget = Notification.Name("SafariChrome.openSettingsTarget")
}

/// Top-level menu commands. Split into its own `Commands`-conforming type so we can use
/// `@Environment(\.openWindow)` for the windowed surfaces (Sync, Passkeys, Settings).
struct SafariCommands: Commands {
    let browser: BrowserViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .toolbar) {
            Button("Show Tab Overview") {
                withAnimation(.smooth) { browser.showTabs.toggle() }
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])

            Button("Reload Page") { browser.reloadOrStop() }
                .keyboardShortcut("r", modifiers: [.command])

            Button("Find on Page…") { browser.openFindBar() }
                .keyboardShortcut("f", modifiers: [.command])
        }

        // View menu — zoom, reader, inspector.
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { browser.zoomIn() }
                .keyboardShortcut("=", modifiers: [.command])
            Button("Zoom Out") { browser.zoomOut() }
                .keyboardShortcut("-", modifiers: [.command])
            Button("Actual Size") { browser.zoomReset() }
                .keyboardShortcut("0", modifiers: [.command])
            Divider()
            Button("Show Reader") {
                withAnimation(.smooth(duration: 0.22)) { browser.readerModeOn.toggle() }
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            Button("Translate Page…") { browser.showTranslationPopover = true }
            Divider()
            Button("Show Web Inspector") {
                withAnimation(.smooth(duration: 0.22)) { browser.showInspector.toggle() }
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        CommandMenu("History") {
            Button("Show All History") { browser.showHistorySheet = true }
                .keyboardShortcut("y", modifiers: [.command])
            Divider()
            ForEach(browser.history.prefix(5)) { entry in
                Button(entry.title) { browser.urlText = entry.url }
            }
        }

        CommandMenu("Bookmarks") {
            Button("Show Bookmarks") { browser.showBookmarksSheet = true }
                .keyboardShortcut("b", modifiers: [.command, .option])
            Button("Add Bookmark…") { browser.showAddBookmarkSheet = true }
                .keyboardShortcut("d", modifiers: [.command])
        }

        // File menu additions — including the real New Private Window spawn.
        CommandGroup(after: .newItem) {
            Button("New Private Window") { openWindow(id: "private-browser") }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(after: .windowList) {
            Button("Settings for This Website…") { browser.showSiteSettingsSheet = true }
            Divider()
            Button("Set Up Sync…")        { openWindow(id: "sync") }
            Button("Manage Passkeys…")     { openWindow(id: "passkeys") }
            Divider()
            Button("Add to Dock…")         { browser.showAddToDockPopover = true }
        }

        CommandGroup(after: .appInfo) {
            Button("Welcome to Safari…") { browser.showWelcomePanel = true }
        }
    }
}
