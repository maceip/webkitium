import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject var state: BrowserState
    @State private var webViewStore = WebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            if webViewStore.isLoading {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color(red: 0.12, green: 0.35, blue: 0.88))
            }

            NavToolbar(webViewStore: webViewStore)

            WebContentView(store: webViewStore)
                .ignoresSafeArea(edges: .bottom)

            Omnibar(webViewStore: webViewStore)
        }
        .onAppear {
            if state.tabs.isEmpty { state.createTab() }
        }
    }
}

struct NavToolbar: View {
    @ObservedObject var webViewStore: WebViewStore
    @EnvironmentObject var state: BrowserState

    var body: some View {
        HStack(spacing: 0) {
            Button { webViewStore.webView?.goBack() } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(!webViewStore.canGoBack)
            .padding(.horizontal, 8)

            Button { webViewStore.webView?.goForward() } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(!webViewStore.canGoForward)
            .padding(.horizontal, 8)

            Button { webViewStore.webView?.reload() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .padding(.horizontal, 8)

            Spacer()

            Button {
                state.showFindBar.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .padding(.horizontal, 8)

            Button {
                let url = webViewStore.currentURL
                let title = webViewStore.currentTitle
                state.bookmarks.append((url: url, title: title))
            } label: {
                Image(systemName: "bookmark")
            }
            .padding(.horizontal, 8)

            Button { state.showHistory.toggle() } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .padding(.horizontal, 8)

            Menu {
                Button("Print", action: {})
                Button("Zoom In", action: {})
                Button("Zoom Out", action: {})
                Button("Settings", action: {})
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .padding(.horizontal, 8)
        }
        .font(.system(size: 16))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

/// Bottom address bar matching Android's layout
struct Omnibar: View {
    @ObservedObject var webViewStore: WebViewStore
    @State private var text = ""
    @State private var isFocused = false
    @FocusState private var fieldFocused: Bool

    private let accentBlue = Color(red: 0.12, green: 0.35, blue: 0.88)

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentBlue)

            TextField("Search or enter address", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($fieldFocused)
                .submitLabel(.go)
                .onSubmit {
                    guard !text.isEmpty else { return }
                    let url = normalizeURL(text)
                    webViewStore.webView?.load(URLRequest(url: url))
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button { webViewStore.webView?.reload() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }

            Button {} label: {
                Image(systemName: "star")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(fieldFocused ? accentBlue : Color(.separator), lineWidth: fieldFocused ? 2 : 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    private func normalizeURL(_ input: String) -> URL {
        if input.hasPrefix("http://") || input.hasPrefix("https://") {
            return URL(string: input) ?? URL(string: "https://\(input)")!
        }
        if input.contains(".") && !input.contains(" ") {
            return URL(string: "https://\(input)")!
        }
        let q = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
        return URL(string: "https://duckduckgo.com/?q=\(q)")!
    }
}
