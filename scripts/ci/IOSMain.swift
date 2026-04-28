import SwiftUI
import WebKit

@main
struct WebkitiumiOS: App {
    @StateObject private var browserState = BrowserWindowState()

    var body: some Scene {
        WindowGroup {
            iOSBrowserView()
                .environmentObject(browserState)
        }
    }
}

struct iOSBrowserView: View {
    @EnvironmentObject var state: BrowserWindowState
    @State private var urlText = "https://example.com"

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            iOSWebView(urlString: state.activeTab?.urlString ?? "https://example.com")
        }
        .onAppear {
            if state.tabs.isEmpty {
                state.createTab()
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button(action: {}) { Image(systemName: "chevron.left") }
            Button(action: {}) { Image(systemName: "chevron.right") }
            Button(action: {}) { Image(systemName: "arrow.clockwise") }

            HStack {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Search or enter address", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .onSubmit {
                        if let tab = state.activeTab,
                           let idx = state.tabs.firstIndex(where: { $0.id == tab.id }) {
                            state.tabs[idx].urlString = urlText
                        }
                    }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            Button(action: {}) { Image(systemName: "bookmark") }
            Button(action: {}) { Image(systemName: "square.and.arrow.up") }
            Menu {
                Button("New Tab", action: { state.createTab() })
                Button("History", action: {})
                Button("Bookmarks", action: {})
                Button("Settings", action: {})
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct iOSWebView: UIViewRepresentable {
    let urlString: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}
}
