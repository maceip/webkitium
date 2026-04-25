// Top-level window content -- three-slot layout shell per
// design/components/shell/SPEC.md.
//
//     NavigationSplitView
//       sidebar:  workspace search + tab list + history + bookmarks + footer
//       detail :  per-tab toolbar (nav buttons + omnibar + actions)
//                 above the WKWebView content

import SwiftUI
import WebKit

struct RootView: View {
    @EnvironmentObject private var palette: PaletteProvider
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var browserState = BrowserWindowState()

    @State private var sidebarVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            contentColumn
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if browserState.tabs.isEmpty {
                browserState.createTab()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTabCommand)) { _ in
            browserState.createTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeTabCommand)) { _ in
            if let id = browserState.activeTabId {
                browserState.closeTab(id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .restoreTabCommand)) { _ in
            browserState.restoreClosedTab()
        }
        .onReceive(NotificationCenter.default.publisher(for: .findCommand)) { _ in
            browserState.showFindBar.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomInCommand)) { _ in
            browserState.zoomLevel = min(browserState.zoomLevel + 0.1, 3.0)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomOutCommand)) { _ in
            browserState.zoomLevel = max(browserState.zoomLevel - 0.1, 0.3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .zoomResetCommand)) { _ in
            browserState.zoomLevel = 1.0
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            workspaceSearch
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            tabList

            sidebarSections

            Spacer(minLength: 0)

            sidebarFooter
        }
        .background(.thinMaterial)
    }

    private var workspaceSearch: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            Text("Search tabs, spaces, history")
                .font(.system(size: 12))
                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.semantic(.surfaceSunken, colorScheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    palette.semantic(.borderSubtle, colorScheme: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private var tabList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    sectionHeader("TABS")
                    Spacer()
                    Button {
                        browserState.createTab()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                    }
                    .buttonStyle(.plain)
                    .help("New Tab (⌘T)")
                }
                .padding(.horizontal, 8)

                ForEach(browserState.tabs) { tab in
                    sidebarRow(
                        id: tab.id.uuidString,
                        icon: tab.isLoading ? "arrow.triangle.2.circlepath" : "globe",
                        label: tab.title.isEmpty ? "New Tab" : tab.title,
                        isActive: browserState.activeTabId == tab.id,
                        onTap: { browserState.activeTabId = tab.id },
                        onClose: { browserState.closeTab(tab.id) }
                    )
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private var sidebarSections: some View {
        VStack(alignment: .leading, spacing: 2) {
            Divider().padding(.horizontal, 12).padding(.vertical, 4)

            Button {
                browserState.showHistory.toggle()
                browserState.showBookmarks = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text("History")
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(browserState.history.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                }
                .foregroundStyle(palette.semantic(
                    browserState.showHistory ? .textPrimary : .textSecondary,
                    colorScheme: colorScheme
                ))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            Button {
                browserState.showBookmarks.toggle()
                browserState.showHistory = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 12))
                    Text("Bookmarks")
                        .font(.system(size: 13))
                    Spacer()
                    Text("\(browserState.bookmarks.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                }
                .foregroundStyle(palette.semantic(
                    browserState.showBookmarks ? .textPrimary : .textSecondary,
                    colorScheme: colorScheme
                ))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)

            if browserState.showHistory {
                historyList
            }
            if browserState.showBookmarks {
                bookmarksList
            }
        }
    }

    private var historyList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(browserState.history.prefix(50)) { item in
                    Button {
                        if let tab = browserState.activeTab {
                            browserState.updateTab(id: tab.id) { $0.urlString = item.url }
                        } else {
                            browserState.createTab(url: item.url)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title.isEmpty ? item.url : item.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Text(item.url)
                                .font(.system(size: 10))
                                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.horizontal, 12)
    }

    private var bookmarksList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(browserState.bookmarks) { bm in
                    HStack {
                        Button {
                            if let tab = browserState.activeTab {
                                browserState.updateTab(id: tab.id) { $0.urlString = bm.url }
                            } else {
                                browserState.createTab(url: bm.url)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bm.title.isEmpty ? bm.url : bm.title)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                                Text(bm.url)
                                    .font(.system(size: 10))
                                    .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Button {
                            browserState.removeBookmark(bm.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                }
            }
        }
        .frame(maxHeight: 200)
        .padding(.horizontal, 12)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            .padding(.vertical, 4)
    }

    private func sidebarRow(id: String, icon: String, label: String,
                             isActive: Bool, onTap: @escaping () -> Void,
                             onClose: (() -> Void)? = nil) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(isActive ? palette.semantic(.accentFill, colorScheme: colorScheme) : .clear)
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 2)

            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(
                    palette.semantic(isActive ? .textPrimary : .textSecondary,
                                     colorScheme: colorScheme)
                )

            Text(label)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundStyle(
                    palette.semantic(isActive ? .textPrimary : .textSecondary,
                                     colorScheme: colorScheme)
                )

            Spacer()

            if let onClose {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                }
                .buttonStyle(.plain)
                .opacity(isActive ? 1 : 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive
                      ? palette.semantic(.accentFillSubtle, colorScheme: colorScheme)
                      : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Button {
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Circle()
                .fill(palette.semantic(.accentFill, colorScheme: colorScheme))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("W")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            palette.semantic(.textOnBrand, colorScheme: colorScheme)
                        )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.semantic(.borderSubtle, colorScheme: colorScheme))
                .frame(height: 1)
        }
    }

    // MARK: - Content column

    private var contentColumn: some View {
        VStack(spacing: 0) {
            if let activeTab = browserState.activeTab {
                perTabToolbar(tab: activeTab)

                Rectangle()
                    .fill(palette.semantic(.borderSubtle, colorScheme: colorScheme))
                    .frame(height: 1)

                if browserState.showFindBar {
                    findBar
                }

                webContent(tab: activeTab)
            } else {
                emptyState
            }
        }
    }

    private func perTabToolbar(tab: TabState) -> some View {
        HStack(spacing: 4) {
            navButton(systemName: "chevron.backward", help: "Back (⌘[)",
                      enabled: tab.canGoBack) {
                NotificationCenter.default.post(name: .goBackCommand, object: tab.id)
            }
            navButton(systemName: "chevron.forward", help: "Forward (⌘])",
                      enabled: tab.canGoForward) {
                NotificationCenter.default.post(name: .goForwardCommand, object: tab.id)
            }
            navButton(systemName: tab.isLoading ? "xmark" : "arrow.clockwise",
                      help: tab.isLoading ? "Stop" : "Reload (⌘R)",
                      enabled: true) {
                NotificationCenter.default.post(name: .reloadCommand, object: tab.id)
            }

            Omnibar()
                .padding(.horizontal, 8)

            navButton(systemName: "bookmark", help: "Bookmark (⌘D)", enabled: true) {
                browserState.addBookmark(url: tab.urlString, title: tab.title)
            }
            navButton(systemName: "puzzlepiece.extension", help: "Extensions", enabled: true) {}
            navButton(systemName: "ellipsis", help: "More", enabled: true) {}
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 44)
        .background(palette.semantic(.surfaceChrome, colorScheme: colorScheme))
    }

    private func navButton(systemName: String, help: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(palette.semantic(
                    enabled ? .textSecondary : .textTertiary,
                    colorScheme: colorScheme
                ))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))

            TextField("Find in page", text: $browserState.findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .onSubmit {
                    if let id = browserState.activeTabId {
                        NotificationCenter.default.post(name: .findInPageCommand,
                                                        object: (id, browserState.findQuery))
                    }
                }

            Button {
                browserState.showFindBar = false
                browserState.findQuery = ""
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(palette.semantic(.surfaceChrome, colorScheme: colorScheme))
    }

    private func webContent(tab: TabState) -> some View {
        WebContentViewWrapper(
            tabId: tab.id,
            browserState: browserState,
            zoomLevel: browserState.zoomLevel
        )
    }

    private var emptyState: some View {
        ZStack {
            palette.semantic(.surfaceCanvas, colorScheme: colorScheme)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                Text("No tabs open")
                    .font(.system(size: 16))
                    .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
                Button("New Tab") {
                    browserState.createTab()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

struct WebContentViewWrapper: View {
    let tabId: UUID
    @ObservedObject var browserState: BrowserWindowState
    let zoomLevel: Double

    var body: some View {
        if let index = browserState.tabs.firstIndex(where: { $0.id == tabId }) {
            WebContentView(
                tabId: tabId,
                urlString: $browserState.tabs[index].urlString,
                title: $browserState.tabs[index].title,
                canGoBack: $browserState.tabs[index].canGoBack,
                canGoForward: $browserState.tabs[index].canGoForward,
                isLoading: $browserState.tabs[index].isLoading,
                onNavigationError: { url, msg in
                    // Error page rendered by WebContentView coordinator
                },
                onNewTab: { url in
                    browserState.createTab(url: url.absoluteString)
                },
                onDownloadStarted: { url in
                    // Downloads handled by WKWebView natively
                },
                onPermissionRequest: { origin, kind in
                    // Permissions handled via WKWebView's prompt dialog
                }
            )
            .onReceive(NotificationCenter.default.publisher(for: .goBackCommand)) { note in
                guard let id = note.object as? UUID, id == tabId else { return }
                goBack()
            }
            .onReceive(NotificationCenter.default.publisher(for: .goForwardCommand)) { note in
                guard let id = note.object as? UUID, id == tabId else { return }
                goForward()
            }
            .onReceive(NotificationCenter.default.publisher(for: .reloadCommand)) { note in
                guard let id = note.object as? UUID, id == tabId else { return }
                reload()
            }
            .onChange(of: browserState.tabs[index].urlString) { newUrl in
                browserState.addHistoryEntry(url: newUrl, title: browserState.tabs[index].title)
            }
        }
    }

    private func goBack() {
        // WKWebView manages its own nav stack; back/forward handled
        // automatically by allowsBackForwardNavigationGestures and the
        // WKWebView.goBack() call from NSViewRepresentable coordinator.
    }

    private func goForward() {}
    private func reload() {}
}

// MARK: - Notification names for keyboard commands

extension Notification.Name {
    static let newTabCommand = Notification.Name("webkitium.newTab")
    static let closeTabCommand = Notification.Name("webkitium.closeTab")
    static let restoreTabCommand = Notification.Name("webkitium.restoreTab")
    static let findCommand = Notification.Name("webkitium.find")
    static let goBackCommand = Notification.Name("webkitium.goBack")
    static let goForwardCommand = Notification.Name("webkitium.goForward")
    static let reloadCommand = Notification.Name("webkitium.reload")
    static let findInPageCommand = Notification.Name("webkitium.findInPage")
    static let zoomInCommand = Notification.Name("webkitium.zoomIn")
    static let zoomOutCommand = Notification.Name("webkitium.zoomOut")
    static let zoomResetCommand = Notification.Name("webkitium.zoomReset")
    static let printCommand = Notification.Name("webkitium.print")
    static let bookmarkCommand = Notification.Name("webkitium.bookmark")
}
