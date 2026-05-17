import SwiftUI

/// Adaptive root. Branches on `horizontalSizeClass`:
///   - `.compact` (iPhone portrait, iPad Split View, Slide Over): mobile
///     chrome — bottom URL bar, single pane, ⋯ menu as consolidated entry.
///   - `.regular` (iPad full-screen, iPhone Plus/Pro Max landscape): desktop
///     chrome — `NavigationSplitView` with sidebar + tab strip + top URL
///     toolbar + WebView, mirroring `chrome/macos/Sources/Webkitium/RootView.swift`.
struct iOSRootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        switch sizeClass {
        case .compact:
            iOSRootViewCompact()
        default:
            iOSRootViewRegular()
        }
    }
}

/// Compact (iPhone / Split View) layout. Page surface above a bottom URL
/// bar; the ⋯ button in the URL bar is the consolidated entry to
/// bookmarks, history, settings, etc. No sidebar.
struct iOSRootViewCompact: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser

        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if browser.findBarOpen {
                CompactFindOnPageBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            BottomURLBar()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.smooth(duration: 0.22), value: browser.findBarOpen)
        .fullScreenCover(isPresented: $browserBinding.showTabs) {
            iOSTabGridView()
                .environment(browser)
        }
        .sheet(isPresented: $browserBinding.showBookmarksSheet) {
            placeholderSheet("Bookmarks", "book.closed")
        }
        .sheet(isPresented: $browserBinding.showHistorySheet) {
            placeholderSheet("History", "clock.arrow.circlepath")
        }
        .sheet(isPresented: $browserBinding.showDownloadsPopover) {
            placeholderSheet("Downloads", "arrow.down.circle")
        }
        .sheet(isPresented: $browserBinding.showSettings) {
            iOSSettingsView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let tab = browser.selectedTab {
            WebContentArea(webView: browser.webView(for: tab))
        } else {
            iOSStartPage()
        }
    }

    private func placeholderSheet(_ title: String, _ symbol: String) -> some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: symbol)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.title2.weight(.semibold))
                Text("Content for \(title) will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Compact find-on-page bar that sits above the URL bar when active.
private struct CompactFindOnPageBar: View {
    @Environment(BrowserViewModel.self) private var browser
    @FocusState private var fieldFocused: Bool

    var body: some View {
        @Bindable var b = browser
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Find on Page", text: $b.findText)
                .textInputAutocapitalization(.never)
                .focused($fieldFocused)
                .onChange(of: browser.findText) { _, _ in browser.recomputeFindMatches() }
            if browser.findMatchCount > 0 {
                Text("\(browser.findCurrentIndex) of \(browser.findMatchCount)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Button(action: { browser.previousFindMatch() }) {
                Image(systemName: "chevron.up")
            }
            .disabled(browser.findMatchCount == 0)
            Button(action: { browser.nextFindMatch() }) {
                Image(systemName: "chevron.down")
            }
            .disabled(browser.findMatchCount == 0)
            Button("Done") { browser.closeFindBar() }
                .font(.system(size: 15, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.thinMaterial)
        .onAppear { fieldFocused = true }
    }
}
