import SwiftUI
import WebKit

struct WebContentView: NSViewRepresentable {
    let tabId: UUID
    @Binding var urlString: String
    @Binding var title: String
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var isLoading: Bool
    var onNavigationError: ((String, String) -> Void)?
    var onNewTab: ((URL) -> Void)?
    var onDownloadStarted: ((String) -> Void)?
    var onPermissionRequest: ((String, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore

        let prefs = WKPreferences()
        prefs.isElementFullscreenEnabled = true
        config.preferences = prefs

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true

        context.coordinator.webView = webView
        context.coordinator.observeProperties(webView)

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebContentView
        weak var webView: WKWebView?
        private var observations: [NSKeyValueObservation] = []

        init(_ parent: WebContentView) {
            self.parent = parent
        }

        func observeProperties(_ webView: WKWebView) {
            observations = [
                webView.observe(\.title) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.title = wv.title ?? ""
                    }
                },
                webView.observe(\.canGoBack) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.canGoBack = wv.canGoBack
                    }
                },
                webView.observe(\.canGoForward) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.canGoForward = wv.canGoForward
                    }
                },
                webView.observe(\.isLoading) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.isLoading = wv.isLoading
                    }
                },
                webView.observe(\.url) { [weak self] wv, _ in
                    DispatchQueue.main.async {
                        self?.parent.urlString = wv.url?.absoluteString ?? ""
                    }
                },
            ]
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.onNavigationError?(
                webView.url?.absoluteString ?? "",
                error.localizedDescription
            )
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let failedUrl = webView.url?.absoluteString ?? ""
            loadErrorPage(in: webView, failedUrl: failedUrl, message: error.localizedDescription)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                      for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if let url = navigationAction.request.url {
                parent.onNewTab?(url)
            }
            return nil
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.shouldPerformDownload {
                return .download
            }
            return .allow
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
            if !navigationResponse.canShowMIMEType {
                return .download
            }
            return .allow
        }

        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction,
                      didBecome download: WKDownload) {
            parent.onDownloadStarted?(download.originalRequest?.url?.absoluteString ?? "")
        }

        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse,
                      didBecome download: WKDownload) {
            parent.onDownloadStarted?(download.originalRequest?.url?.absoluteString ?? "")
        }

        func webView(_ webView: WKWebView,
                      decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                      initiatedBy frame: WKFrameInfo,
                      type: WKMediaCaptureType) async -> WKPermissionDecision {
            parent.onPermissionRequest?(origin.host, type.description)
            return .prompt
        }

        private func loadErrorPage(in webView: WKWebView, failedUrl: String, message: String) {
            let html = """
            <!DOCTYPE html>
            <html><head><meta charset="utf-8"/>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                     display: flex; flex-direction: column; align-items: center;
                     justify-content: center; height: 100vh; margin: 0;
                     background: #1a1a2e; color: #e0e0e0; }
              h1 { font-size: 24px; margin-bottom: 8px; color: #ff6b6b; }
              p { font-size: 14px; color: #a0a0a0; max-width: 480px; text-align: center; }
              code { background: #2a2a3e; padding: 2px 6px; border-radius: 4px; }
              button { margin-top: 16px; padding: 8px 24px; border: none;
                       border-radius: 6px; background: #4a9eff; color: #fff;
                       cursor: pointer; font-size: 14px; }
            </style></head><body>
            <h1>This page isn\u{2019}t working</h1>
            <p><code>\(failedUrl.htmlEscaped)</code></p>
            <p>\(message.htmlEscaped)</p>
            <button onclick="history.back()">Go back</button>
            </body></html>
            """
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

private extension String {
    var htmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private extension WKMediaCaptureType {
    var description: String {
        switch self {
        case .camera: return "Camera"
        case .microphone: return "Microphone"
        case .cameraAndMicrophone: return "Camera & Microphone"
        @unknown default: return "Media"
        }
    }
}
