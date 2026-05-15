import SwiftUI

/// Top-level browser window content.
struct RootView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Namespace private var tabMorph

    /// Persisted in NSUserDefaults — when false, the Welcome panel auto-shows on first
    /// launch (regular windows only, never Private).
    @AppStorage("SafariChrome.hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        @Bindable var browserBinding = browser

        NavigationSplitView(columnVisibility: .constant(.all)) {
            SidebarView(tabMorph: tabMorph)
                // Wide drag range so the framework divider has room to resize; matches
                // Safari which lets you pull the sidebar from skinny-tab-only (~120pt) to
                // wide-with-titles (~420pt).
                .navigationSplitViewColumnWidth(min: 120, ideal: 220, max: 420)
                .toolbar(removing: .sidebarToggle)
                // Private tint on the sidebar container.
                .privateChromeTint(browser.isPrivate)
        } detail: {
            VStack(spacing: 0) {
                TabStripView(tabMorph: tabMorph)
                    // macOS 26 modifier: lets the tab strip's content + background
                    // bleed under the translucent sidebar so horizontal scrolling
                    // visually continues across the divider, matching Safari 26.
                    .backgroundExtensionEffect()
                if browser.findBarOpen {
                    FindOnPageBar()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Divider()
                contentStack
            }
            // Private tint on the entire detail column — covers tab strip, find bar,
            // and content surface.
            .privateChromeTint(browser.isPrivate)
            .toolbar { TopToolbar() }
            // Private tint on the window toolbar itself — extends the look into the
            // chrome rendered by the system above our VStack.
            .toolbarBackground(
                browser.isPrivate ? PrivateBrowsingPalette.toolbarBackground : Color.clear,
                for: .windowToolbar)
            .toolbarBackground(
                browser.isPrivate ? .visible : .automatic,
                for: .windowToolbar)
            .toolbarColorScheme(browser.isPrivate ? .dark : nil, for: .windowToolbar)
            .overlay {
                if browser.showTabs {
                    TabOverviewView(tabMorph: tabMorph)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .center) {
                if browser.showZoomHUD {
                    ZoomHUD().transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) {
                StatusBarOverlay()
            }
            .animation(.smooth, value: browser.showTabs)
            .animation(.smooth(duration: 0.22), value: browser.findBarOpen)
            .animation(.smooth(duration: 0.18), value: browser.showZoomHUD)
            .animation(.smooth(duration: 0.18), value: browser.hoveredLink)
            .sheet(isPresented: $browserBinding.showSiteSettingsSheet) { SiteSettingsSheet() }
            .sheet(isPresented: $browserBinding.showHistorySheet)      { HistoryView() }
            .sheet(isPresented: $browserBinding.showBookmarksSheet)    { BookmarksManagerView() }
            .sheet(isPresented: $browserBinding.showAddBookmarkSheet)  { AddBookmarkSheet() }
            .sheet(isPresented: $browserBinding.showAddToDockPopover)  { AddToDockPopover() }
            .sheet(isPresented: $browserBinding.showWelcomePanel) {
                WelcomePanel()
                    .onDisappear { hasSeenWelcome = true }
            }
            .onAppear {
                // Auto-open Welcome the first time the user launches the app. Suppressed
                // in Private windows so it doesn't break the "no traces" expectation.
                if !hasSeenWelcome && !browser.isPrivate {
                    browser.showWelcomePanel = true
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// Stacks the page content with the optional reader overlay and the optional
    /// docked Web Inspector pane.
    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 0) {
            ZStack {
                ContentRouter()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if browser.readerModeOn {
                    ReaderModeView()
                        .transition(.opacity)
                }
            }
            if browser.showInspector {
                WebInspectorPane()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.22), value: browser.readerModeOn)
        .animation(.smooth(duration: 0.22), value: browser.showInspector)
    }
}

/// Picks what to render in the right pane below the tab strip based on the sidebar
/// selection. For an open tab (the default case), we hand back the real `WKWebView`
/// for that tab via `WebContentArea`. Saved-leaves still show placeholder panes.
private struct ContentRouter: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        switch browser.sidebarSelection {
        case .leaf(.bookmarks):     PlaceholderPane(title: "Bookmarks", symbol: "book.closed")
        case .leaf(.readingList):   PlaceholderPane(title: "Reading List", symbol: "eyeglasses")
        case .leaf(.sharedWithYou): PlaceholderPane(title: "Shared with You", symbol: "person.2")
        default:
            if let tab = browser.selectedTab {
                WebContentArea(webView: browser.webView(for: tab))
            } else {
                PlaceholderPane(title: "New Tab", symbol: "globe")
            }
        }
    }
}

private struct PlaceholderPane: View {
    let title: String
    let symbol: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Content for \(title) will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
