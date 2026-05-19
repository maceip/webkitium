import AppKit
import SwiftUI
import WebKit

/// In-process view backed by pinned `WebKit.framework` (via `WEBKIT_FRAMEWORK_PATH` / `DYLD_FRAMEWORK_PATH`).
@MainActor
final class TabWebViewRegistry {
    static let shared = TabWebViewRegistry()
    private var views: [UUID: WKWebView] = [:]

    private init() {}

    func register(tabID: UUID, view: WKWebView) {
        views[tabID] = view
    }

    func unregister(tabID: UUID) {
        views.removeValue(forKey: tabID)
    }

    func view(for tabID: UUID) -> WKWebView? { views[tabID] }

    func load(tabID: UUID, url: String) {
        guard let view = views[tabID], let requestURL = URL(string: url) else { return }
        view.load(URLRequest(url: requestURL))
    }

    func goBack(tabID: UUID) -> Bool {
        guard let view = views[tabID], view.canGoBack else { return false }
        view.goBack()
        return true
    }

    func goForward(tabID: UUID) -> Bool {
        guard let view = views[tabID], view.canGoForward else { return false }
        view.goForward()
        return true
    }

    func reload(tabID: UUID) {
        views[tabID]?.reload()
    }

    func stop(tabID: UUID) {
        views[tabID]?.stopLoading()
    }
}

struct PinnedEngineWebView: NSViewRepresentable {
    let tabID: UUID
    let host: TabEngineHost

    func makeCoordinator() -> Coordinator {
        Coordinator(tabID: tabID, host: host)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        TabWebViewRegistry.shared.register(tabID: tabID, view: view)
        let url = host.displayURL
        if !url.isEmpty, let u = URL(string: url) {
            view.load(URLRequest(url: u))
        }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        TabWebViewRegistry.shared.unregister(tabID: coordinator.tabID)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let tabID: UUID
        let host: TabEngineHost

        init(tabID: UUID, host: TabEngineHost) {
            self.tabID = tabID
            self.host = host
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            host.setLoading(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            host.setLoading(false)
            if let url = webView.url?.absoluteString {
                host.syncFromEngine(url: url, title: webView.title ?? url)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            host.setLoading(false)
        }
    }
}
