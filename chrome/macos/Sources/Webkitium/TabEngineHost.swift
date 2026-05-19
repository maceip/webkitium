import Foundation

/// Per-tab navigation against the pinned engine (external MiniBrowser process).
/// Chrome UI stays in-process; page pixels come from our WebKit build only.
@MainActor
final class TabEngineHost {
    private weak var browser: BrowserViewModel?
    private let tabID: UUID
    private(set) var backStack: [String] = []
    private(set) var forwardStack: [String] = []

    init(tabID: UUID, browser: BrowserViewModel) {
        self.tabID = tabID
        self.browser = browser
    }

    var displayURL: String {
        browser?.tabs.first(where: { $0.id == tabID })?.url ?? ""
    }

    func load(_ raw: String) {
        guard let browser else { return }
        guard let resolved = SearchEngine.normalize(raw)?.absoluteString else { return }
        pushAndNavigate(to: resolved, recordBack: true)
    }

    func loadResolvedURL(_ url: String) {
        pushAndNavigate(to: url, recordBack: true)
    }

    func goBack() -> Bool {
        guard let prev = backStack.popLast() else { return false }
        if let current = currentURL(), !current.isEmpty {
            forwardStack.append(current)
        }
        pushAndNavigate(to: prev, recordBack: false)
        return true
    }

    func goForward() -> Bool {
        guard let next = forwardStack.popLast() else { return false }
        if let current = currentURL(), !current.isEmpty {
            backStack.append(current)
        }
        pushAndNavigate(to: next, recordBack: false)
        return true
    }

    func reload() {
        guard let url = currentURL(), !url.isEmpty else { return }
        PinnedEngineLaunch.open(url: url)
    }

    func stop() {
        // MiniBrowser is a separate process; stop is a no-op until in-process embed lands.
    }

    private func currentURL() -> String? {
        browser?.tabs.first(where: { $0.id == tabID })?.url
    }

    private func pushAndNavigate(to url: String, recordBack: Bool) {
        guard let browser,
              let idx = browser.tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if recordBack, let cur = currentURL(), !cur.isEmpty, cur != url {
            backStack.append(cur)
            forwardStack.removeAll()
        }
        browser.tabs[idx].url = url
        browser.tabs[idx].title = url
        browser.tabs[idx].canGoBack = !backStack.isEmpty
        browser.tabs[idx].canGoForward = !forwardStack.isEmpty
        browser.tabs[idx].isLoading = false
        browser.tabs[idx].loadProgress = 1
        PinnedEngineLaunch.open(url: url)
    }

}
