import SwiftUI
import WebKit

@MainActor
final class WebViewStore: ObservableObject {
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var currentURL = ""
    @Published var currentTitle = ""

    var webView: WKWebView?
}

struct WebContentView: UIViewRepresentable {
    @ObservedObject var store: WebViewStore

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if let url = URL(string: "https://example.com") {
            webView.load(URLRequest(url: url))
        }

        DispatchQueue.main.async { store.webView = webView }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let store: WebViewStore

        init(store: WebViewStore) { self.store = store }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            update(webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            update(webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            update(webView)
        }

        private func update(_ webView: WKWebView) {
            Task { @MainActor in
                store.canGoBack = webView.canGoBack
                store.canGoForward = webView.canGoForward
                store.isLoading = webView.isLoading
                store.currentURL = webView.url?.absoluteString ?? ""
                store.currentTitle = webView.title ?? ""
            }
        }
    }
}
