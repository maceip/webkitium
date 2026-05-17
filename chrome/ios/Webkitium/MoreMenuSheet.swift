import SwiftUI

/// Consolidated menu reachable from the ⋯ button in the bottom URL bar.
/// Matches Safari iOS 26's pattern of folding bookmarks/share/tabs/etc. into
/// a single entry point so the bottom chrome stays minimal.
struct MoreMenuSheet: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    row("plus",                 "New Tab")           { browser.newTab(); dismiss() }
                    row("square.stack",         "Open Tabs (\(browser.tabs.count))") {
                        dismissThen { browser.showTabs = true }
                    }
                }
                Section {
                    row("book.closed",          "Bookmarks")         {
                        dismissThen { browser.showBookmarksSheet = true }
                    }
                    row("eyeglasses",           "Reading List")      { /* TODO features.yaml: reading_list_add */ }
                    row("clock.arrow.circlepath","History")          {
                        dismissThen { browser.showHistorySheet = true }
                    }
                    row("arrow.down.circle",    "Downloads (\(browser.downloads.count))") {
                        dismissThen { browser.showDownloadsPopover = true }
                    }
                }
                Section {
                    row("square.and.arrow.up",  "Share")             { /* TODO features.yaml: share_page */ }
                    row("magnifyingglass",      "Find on Page")      { browser.openFindBar(); dismiss() }
                    row("textformat.size",      "Page Settings")     {
                        dismissThen { browser.showPageSettingsMenu = true }
                    }
                }
                Section {
                    row("gearshape",            "Settings")          {
                        dismissThen { browser.showSettings = true }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
        }
    }

    /// Dismiss the More menu first, then run the next-modal trigger after the
    /// dismiss animation lands. iOS only renders one sheet per host at a time,
    /// so chaining without this delay silently swallows the second present.
    private func dismissThen(_ work: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            work()
        }
    }
}
