import SwiftUI

/// Bottom URL bar — copies the Safari iOS 26 layout verbatim.
/// Left: back chevron (greyed when `!canGoBack`).
/// Center: glass-effect pill, shows domain when collapsed, full URL when focused,
///         loading bar across the bottom of the pill while `isLoading`.
/// Right: ⋯ button opening the consolidated MoreMenuSheet.
struct BottomURLBar: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var showMoreMenu: Bool = false
    @FocusState private var urlFocused: Bool

    var body: some View {
        @Bindable var browserBinding = browser

        HStack(spacing: 12) {
            backButton
            urlPill
            moreButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showMoreMenu) {
            MoreMenuSheet()
                .environment(browser)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var backButton: some View {
        Button(action: { browser.goBack() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(browser.canGoBack ? Color.primary : Color.secondary.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(!browser.canGoBack)
    }

    private var urlPill: some View {
        @Bindable var browserBinding = browser
        let isSecure = browser.selectedTab?.url.hasPrefix("https://") == true
        return HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.23, green: 0.51, blue: 0.96))
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.75), radius: 5)
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.45), radius: 10)
                .opacity(isSecure ? 1.0 : 0.0)
                .animation(.smooth(duration: 0.25), value: isSecure)
            if !urlFocused {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            TextField("Search or enter website", text: $browserBinding.urlText)
                .focused($urlFocused)
                .font(.system(size: 15))
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .onSubmit {
                    browser.navigateActive(to: browser.urlText)
                    urlFocused = false
                }
            if urlFocused && !browser.urlText.isEmpty {
                Button(action: { browser.urlText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.tertiarySystemBackground), in: .capsule)
        .overlay(alignment: .bottom) {
            if browser.isLoading {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: proxy.size.width * browser.loadProgress, height: 2)
                        .animation(.smooth, value: browser.loadProgress)
                }
                .frame(height: 2)
                .padding(.horizontal, 2)
            }
        }
        .onChange(of: browser.urlText) { _, _ in
            browser.refreshSuggestions()
        }
    }

    private var moreButton: some View {
        Button(action: { showMoreMenu = true }) {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(.thinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
    }
}
