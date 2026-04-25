import SwiftUI
import WebKit

struct TabState: Identifiable {
    let id = UUID()
    var urlString: String = "https://example.com/"
    var title: String = "New Tab"
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var isLoading: Bool = false
}

struct BookmarkEntry: Identifiable {
    let id = UUID()
    var url: String
    var title: String
}

struct HistoryItem: Identifiable {
    let id = UUID()
    var url: String
    var title: String
    var date: Date = Date()
}

struct ClosedTab {
    var url: String
    var title: String
}

@MainActor
final class BrowserWindowState: ObservableObject {
    @Published var tabs: [TabState] = []
    @Published var activeTabId: UUID?
    @Published var showFindBar = false
    @Published var findQuery = ""
    @Published var zoomLevel: Double = 1.0
    @Published var bookmarks: [BookmarkEntry] = []
    @Published var history: [HistoryItem] = []
    @Published var showHistory = false
    @Published var showBookmarks = false

    private var closedTabStack: [ClosedTab] = []
    private let maxClosedTabs = 25

    var activeTab: TabState? {
        tabs.first(where: { $0.id == activeTabId })
    }

    var activeTabIndex: Int? {
        tabs.firstIndex(where: { $0.id == activeTabId })
    }

    func createTab(url: String = "https://example.com/") {
        let tab = TabState(urlString: url)
        tabs.append(tab)
        activeTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[idx]
        closedTabStack.insert(ClosedTab(url: tab.urlString, title: tab.title), at: 0)
        if closedTabStack.count > maxClosedTabs { closedTabStack.removeLast() }
        tabs.remove(at: idx)

        if activeTabId == id {
            if !tabs.isEmpty {
                activeTabId = tabs[min(idx, tabs.count - 1)].id
            } else {
                activeTabId = nil
            }
        }
    }

    func restoreClosedTab() {
        guard !closedTabStack.isEmpty else { return }
        let closed = closedTabStack.removeFirst()
        createTab(url: closed.url)
    }

    func addBookmark(url: String, title: String) {
        guard !bookmarks.contains(where: { $0.url == url }) else { return }
        bookmarks.append(BookmarkEntry(url: url, title: title))
    }

    func removeBookmark(_ id: UUID) {
        bookmarks.removeAll(where: { $0.id == id })
    }

    func addHistoryEntry(url: String, title: String) {
        guard !url.isEmpty else { return }
        history.insert(HistoryItem(url: url, title: title), at: 0)
        if history.count > 1000 { history.removeLast() }
    }

    func clearHistory() {
        history.removeAll()
    }

    func updateTab(id: UUID, mutate: (inout TabState) -> Void) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&tabs[idx])
    }
}
