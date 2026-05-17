import SwiftUI
import UIKit
@preconcurrency import WebKit

/// One-per-tab handle wrapping a `WKWebView` and the per-tab navigation state.
/// iOS variant of the macOS shell's TabWebView — same KVO pattern, swaps
/// AppKit for UIKit and `NSView` for `UIView`.
@MainActor
final class TabWebView: NSObject, WKNavigationDelegate {
    let webView: WKWebView
    private weak var browser: BrowserViewModel?
    private let tabID: UUID
    private var observers: [NSKeyValueObservation] = []

    init(tabID: UUID, browser: BrowserViewModel, presetWebView: WKWebView? = nil) {
        self.tabID = tabID
        self.browser = browser

        if let preset = presetWebView {
            self.webView = preset
        } else {
            let config = WKWebViewConfiguration()
            if browser.isPrivate {
                config.websiteDataStore = .nonPersistent()
            }
            self.webView = WKWebView(frame: .zero, configuration: config)
        }
        super.init()

        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self

        observers = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
                guard let progress = change.newValue else { return }
                Task { @MainActor in self?.push { $0.loadProgress = progress } }
            },
            webView.observe(\.isLoading, options: [.new, .old]) { [weak self] _, change in
                guard let loading = change.newValue else { return }
                Task { @MainActor in
                    self?.push { $0.isLoading = loading }
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

    static func normalize(_ raw: String) -> URL? {
        URLBridge.normalize(raw)
    }
}

/// SwiftUI wrapper. Hosts a single `WKWebView` as the embedded subview of a
/// container `UIView`; swaps the embedded webview when the selected tab
/// changes so each tab's `WKWebView` keeps its navigation stack.
struct WebContentArea: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        embed(webView, in: host)
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if uiView.subviews.first === webView { return }
        uiView.subviews.forEach { $0.removeFromSuperview() }
        embed(webView, in: uiView)
    }

    private func embed(_ webView: WKWebView, in host: UIView) {
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
