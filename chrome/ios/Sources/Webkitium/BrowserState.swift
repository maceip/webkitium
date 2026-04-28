import SwiftUI

struct TabInfo: Identifiable {
    let id = UUID()
    var urlString: String = "https://example.com/"
    var title: String = "New Tab"
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false
}

@MainActor
final class BrowserState: ObservableObject {
    @Published var tabs: [TabInfo] = []
    @Published var activeTabId: UUID?
    @Published var showFindBar = false
    @Published var findQuery = ""
    @Published var bookmarks: [(url: String, title: String)] = []
    @Published var history: [(url: String, title: String, date: Date)] = []
    @Published var showHistory = false
    @Published var showBookmarks = false

    var activeTab: TabInfo? {
        tabs.first { $0.id == activeTabId }
    }

    var activeTabIndex: Int? {
        tabs.firstIndex { $0.id == activeTabId }
    }

    func createTab(url: String = "https://example.com/") {
        let tab = TabInfo(urlString: url)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if activeTabId == id {
            activeTabId = tabs.last?.id
        }
    }
}
