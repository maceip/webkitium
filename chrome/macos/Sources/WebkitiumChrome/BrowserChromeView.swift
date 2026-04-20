import SwiftUI
import WebKit

struct BrowserTab: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var url: URL
}

struct BrowserChromeView: View {
    @State private var tabs = [
        BrowserTab(title: "Start", url: URL(string: "https://example.com")!)
    ]
    @State private var selectedTab: BrowserTab.ID?
    @State private var addressText = "https://example.com"

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            tabStrip
            Divider()
            selectedPage
        }
        .frame(minWidth: 900, minHeight: 640)
        .onAppear {
            selectedTab = tabs.first?.id
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTabRequested)) { _ in
            addTab()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button("Back") {}
            Button("Forward") {}
            Button("Reload") {}

            TextField("Search or enter website name", text: $addressText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    navigateSelectedTab()
                }

            Button("New Tab") {
                addTab()
            }
        }
        .padding(10)
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tabs) { tab in
                    Button {
                        selectedTab = tab.id
                        addressText = tab.url.absoluteString
                    } label: {
                        Text(tab.title)
                            .lineLimit(1)
                            .frame(width: 160, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var selectedPage: some View {
        if let tab = tabs.first(where: { $0.id == selectedTab }) {
            WebPageView(url: tab.url)
        } else {
            ContentUnavailableView("No Tab", systemImage: "globe")
        }
    }

    private func addTab() {
        let tab = BrowserTab(title: "New Tab", url: URL(string: "https://example.com")!)
        tabs.append(tab)
        selectedTab = tab.id
        addressText = tab.url.absoluteString
    }

    private func navigateSelectedTab() {
        guard let selectedTab, let url = URL(string: addressText) else {
            return
        }

        if let index = tabs.firstIndex(where: { $0.id == selectedTab }) {
            tabs[index].url = url
            tabs[index].title = url.host() ?? url.absoluteString
        }
    }
}

struct WebPageView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}
