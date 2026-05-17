import SwiftUI
@preconcurrency import WebKit

/// One-per-tab handle wrapping a `WKWebView` and the per-tab navigation state we feed
/// back into the chrome. Owned by `BrowserViewModel` via a `[Tab.ID: TabWebView]`
/// registry — never re-created for the same tab, so back/forward history survives tab
/// switching.
///
/// Drives KVO on the underlying `WKWebView` to push four fields into the matching
/// `Tab` struct: `title`, `url`, `isLoading`, `loadProgress`, `canGoBack`, `canGoForward`.
/// That's the data flow the rest of the chrome reads from (URL bar, tab strip cell,
/// toolbar back/forward enable state, loading spinner).
@MainActor
final class TabWebView: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private weak var browser: BrowserViewModel?
    private let tabID: UUID
    private var observers: [NSKeyValueObservation] = []

    /// Accepts an optional pre-warmed `WKWebView` so new tabs can adopt one whose
    /// WebContent process is already running. `BrowserViewModel.wrapper(for:)`
    /// hands one in whenever the pre-warm slot is filled; otherwise we mint a fresh
    /// one (cold) here.
    init(tabID: UUID, browser: BrowserViewModel, presetWebView: WKWebView? = nil) {
        self.tabID = tabID
        self.browser = browser

        if let preset = presetWebView {
            self.webView = preset
        } else {
            let config = WKWebViewConfiguration()
            // Private windows use a non-persistent data store so cookies, localStorage,
            // and history don't survive the window close.
            if browser.isPrivate {
                config.websiteDataStore = .nonPersistent()
            }
            self.webView = WKWebView(frame: .zero, configuration: config)
        }
        super.init()

        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.navigationDelegate = self

        // KVO bindings — the WKWebView pushes state into the matching Tab struct.
        observers = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in self?.push { $0.loadProgress = progress } }
            },
            webView.observe(\.isLoading, options: [.new, .old]) { [weak self] _, change in
                guard let loading = change.newValue else { return }
                Task { @MainActor in
                    self?.push { $0.isLoading = loading }
                    // Loading transitioned true → false = navigation completed.
                    // Record into the suggestions index so the page ranks in
                    // future URL-bar queries. Private windows still call into
                    // the provider; the FFISuggestionProvider for those is
                    // backed by an in-memory DB that dies with the window.
                    if loading == false, change.oldValue == true,
                       let strong = self,
                       let browser = strong.browser,
                       let tab = browser.tabs.first(where: { $0.id == strong.tabID }),
                       !tab.url.isEmpty {
                        await browser.suggestionProvider.recordVisit(
                            title: tab.title, url: tab.url)
                        await browser.historyStore.recordVisit(
                            title: tab.title, url: tab.url)
                        if !browser.isPrivate {
                            CoreSpotlightIndexer.shared.indexVisit(
                                title: tab.title, url: tab.url)
                        }
                        // Persist the tab snapshot so a relaunch restores
                        // the right URL/title — not just the seeded one.
                        browser.persistTabs()
                    }
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, change in
                let title = change.newValue ?? nil
                Task { @MainActor in
                    self?.push { tab in
                        if let t = title, !t.isEmpty { tab.title = t }
                    }
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, change in
                let url = change.newValue ?? nil
                Task { @MainActor in
                    self?.push { tab in
                        if let u = url { tab.url = u.absoluteString }
                    }
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, change in
                guard let v = change.newValue else { return }
                Task { @MainActor in self?.push { $0.canGoBack = v } }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, change in
                guard let v = change.newValue else { return }
                Task { @MainActor in self?.push { $0.canGoForward = v } }
            },
        ]
    }

    deinit {
        observers.forEach { $0.invalidate() }
    }

    /// Mutate the matching `Tab` on the owning view model. Silently drops if the tab
    /// has been closed (the webview will be released by its registry shortly after).
    private func push(_ mutate: (inout Tab) -> Void) {
        guard let browser = browser,
              let idx = browser.tabs.firstIndex(where: { $0.id == tabID }) else { return }
        mutate(&browser.tabs[idx])
    }

    func load(_ rawInput: String) {
        guard let url = TabWebView.normalize(rawInput) else { return }
        webView.load(URLRequest(url: url))
    }
    func reload()  { webView.reload() }
    func stop()    { webView.stopLoading() }
    func goBack()    { webView.goBack() }
    func goForward() { webView.goForward() }

    // MARK: - WKNavigationDelegate (download handling)
    //
    // Convert navigation responses whose MIME type the webview can't render
    // directly into WKDownload + route them through FFIDownloadsManager.
    // The MainActor hop is required because BrowserViewModel.downloadsManager
    // is `@MainActor`.

    func webView(_ webView: WKWebView,
                  decidePolicyFor navigationResponse: WKNavigationResponse) async
                  -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType {
            return .download
        }
        return .allow
    }

    func webView(_ webView: WKWebView,
                  navigationResponse: WKNavigationResponse,
                  didBecome download: WKDownload) {
        Task { @MainActor [weak self] in
            self?.browser?.downloadsManager?.attach(download)
        }
    }

    /// URL normalization — thin wrapper around `browser/url/` (C++). The
    /// heuristic (scheme/dot/search) and search-engine routing both live
    /// in the C ABI; this Swift call just hands the raw string across.
    static func normalize(_ raw: String) -> URL? {
        URLBridge.normalize(raw)
    }
}

/// SwiftUI wrapper. Hosts a single `WKWebView` as the embedded subview of a container
/// `NSView`; swap the embedded webview when the selected tab changes so each tab's
/// `WKWebView` keeps its navigation stack across tab switches.
struct WebContentArea: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let host = NSView()
        embed(webView, in: host)
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Avoid the layout thrash if the same webview is already mounted.
        if nsView.subviews.first === webView { return }
        nsView.subviews.forEach { $0.removeFromSuperview() }
        embed(webView, in: nsView)
    }

    private func embed(_ webView: WKWebView, in host: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            webView.topAnchor.constraint(equalTo: host.topAnchor),
            webView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
    }
}
