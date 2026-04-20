import SwiftUI
import WebKit

struct BrowserTab: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var url: URL
}

struct BrowserChromeView: View {
    @State private var tabs: [BrowserTab]
    @State private var selectedTab: BrowserTab.ID
    @State private var addressText = "https://example.com"

    init() {
        let startTab = BrowserTab(title: "Start", url: URL(string: "https://example.com")!)
        _tabs = State(initialValue: [startTab])
        _selectedTab = State(initialValue: startTab.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            nativeTabs
        }
        .frame(minWidth: 900, minHeight: 640)
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

            Button("Close Tab") {
                closeSelectedTab()
            }
            .disabled(tabs.count == 1)
        }
        .padding(10)
    }

    private var nativeTabs: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabs) { tab in
                WebPageView(url: tab.url)
                    .tabItem {
                        Text(tab.title)
                    }
                    .tag(tab.id)
            }
        }
        .onChange(of: selectedTab) { _, id in
            if let tab = tabs.first(where: { $0.id == id }) {
                addressText = tab.url.absoluteString
            }
        }
    }

    private func addTab() {
        let tab = BrowserTab(title: "New Tab", url: URL(string: "https://example.com")!)
        tabs.append(tab)
        selectedTab = tab.id
        addressText = tab.url.absoluteString
    }

    private func closeSelectedTab() {
        guard tabs.count > 1, let index = tabs.firstIndex(where: { $0.id == selectedTab }) else {
            return
        }

        tabs.remove(at: index)
        let fallbackIndex = min(index, tabs.count - 1)
        selectedTab = tabs[fallbackIndex].id
        addressText = tabs[fallbackIndex].url.absoluteString
    }

    private func navigateSelectedTab() {
        guard let url = URL(string: addressText) else {
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
