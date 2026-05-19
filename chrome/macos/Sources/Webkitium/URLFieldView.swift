import SwiftUI

/// The combined URL / search field. Hosts reader-mode + magnifying icons on the left, the
/// editable text in the center, and reload/stop on the right. The page-load progress fills
/// the field's background. When focused with non-empty text, an autocomplete dropdown
/// slides down underneath.
struct URLFieldView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.openWindow) private var openWindow
    @FocusState private var focused: Bool
    /// Per Safari behavior: certain inline icons (e.g. Add Bookmark "+") only appear
    /// when the pointer is over the URL field. Drives the opacity of those icons.
    @State private var hovering: Bool = false

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            fieldContent
                .background(progressFill, alignment: .leading)
                .glassEffect(.regular, in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(Color.accentColor.opacity(focused ? 0.85 : 0),
                                lineWidth: focused ? 1.5 : 0)
                )
                .onHover { hovering = $0 }
        }
        .animation(.smooth(duration: SafariDecompiled.focusAnimationDuration), value: focused)
        .animation(.smooth(duration: 0.12), value: hovering)
        .onChange(of: focused) { _, newValue in
            browser.urlFieldFocused = newValue
        }
        .overlay(alignment: .top) {
            // Dropdown anchored to the BOTTOM of the URL field by translating downwards.
            if showDropdown {
                URLSuggestionsDropdown(suggestions: browser.urlSuggestions)
                    .offset(y: 38)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)).animation(.smooth(duration: 0.18)),
                        removal:   .opacity.animation(.smooth(duration: 0.12))))
            }
        }
        .animation(.smooth(duration: 0.18), value: showDropdown)
    }

    private var showDropdown: Bool {
        focused && !browser.urlText.isEmpty && !browser.urlSuggestions.isEmpty
    }

    /// HTTPS lock indicator visibility — drives the leading glowing-blue lock.
    /// Reads the active tab's URL (not the URL bar's typing buffer) so the lock
    /// stays visible while the page is loaded but the field isn't focused.
    private var isSecure: Bool {
        (browser.selectedTab?.url ?? "").hasPrefix("https://")
    }

    private var fieldContent: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 6) {
            // Glowing blue HTTPS lock — fades in on https:// URLs, hidden otherwise.
            Image(systemName: "lock.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 0.23, green: 0.51, blue: 0.96))
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.75), radius: 5)
                .shadow(color: Color(red: 0.23, green: 0.51, blue: 0.96).opacity(0.45), radius: 10)
                .opacity(isSecure ? 1.0 : 0.0)
                .animation(.smooth(duration: 0.25), value: isSecure)
                .accessibilityLabel("Connection is secure")

            if browser.hasReaderMode {
                Button {
                    withAnimation(.smooth(duration: 0.22)) { browser.readerModeOn.toggle() }
                } label: {
                    Image(systemName: "text.justify.leading")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(browser.readerModeOn ? Color.accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .help(browser.readerModeOn ? "Hide Reader View" : "Show Reader View")
            }

            // Translation icon — opens the translation popover.
            Button { browser.showTranslationPopover.toggle() } label: {
                Image(systemName: "character.bubble")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Translate Page")
            .popover(isPresented: $browserBinding.showTranslationPopover, arrowEdge: .bottom) {
                TranslationPopover()
            }

            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Hover-only Add Bookmark "+" icon — matches Safari's behavior where
            // certain inline URL-field actions only reveal on pointer hover.
            // Currently disabled when there's no active page.
            Button {
                browser.showAddBookmarkSheet = true
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Add Bookmark")
            .opacity(hovering ? 1 : 0)
            .disabled(browser.selectedTab == nil)

            // Per spec: cursor must be leading-aligned, NOT centered. Centered text
            // alignment caused the caret to jump to mid-field on focus.
            TextField("", text: $browserBinding.urlText,
                       prompt: Text("Search or enter website name").foregroundStyle(.secondary))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .multilineTextAlignment(.leading)
                .focused($focused)
                .onSubmit {
                    // Hand the typed text to the active tab engine host.
                    // normalizes URL vs. search query.
                    browser.navigateActive(to: browser.urlText)
                    focused = false
                }
                // Route every keystroke through `SuggestionProvider` (today: mock; later:
                // FFI). The VM debounces and replaces `urlSuggestions` atomically.
                .onChange(of: browser.urlText) { _, _ in browser.refreshSuggestions() }

            // Page Settings (aA) — zoom + desktop site + website settings link.
            PageSettingsButton()

            // Passkey entry — opens the dedicated Passkey Manager window. Matches
            // Safari's URL-field autofill key icon.
            Button { openWindow(id: "passkeys") } label: {
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Passkeys for this site")

            // Reload / Stop button — swaps icon based on load state.
            Button { browser.reloadOrStop() } label: {
                Image(systemName: browser.isLoading ? "xmark" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help(browser.isLoading ? "Stop" : "Reload This Page")
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }

    /// Progress fill: a translucent accent-colored rectangle that grows from the leading
    /// edge to a fraction of the capsule's width during loading. Matches Safari's
    /// per-tab progress hint inside the URL bar.
    @ViewBuilder
    private var progressFill: some View {
        GeometryReader { proxy in
            if browser.isLoading && browser.loadProgress > 0 && browser.loadProgress < 1 {
                Color.accentColor.opacity(0.18)
                    .frame(width: proxy.size.width * browser.loadProgress)
                    .animation(.smooth(duration: 0.2), value: browser.loadProgress)
            }
        }
    }
}

/// Dropdown of URL suggestions, grouped into Top Hit / History / Bookmarks /
/// Search sections with section headers. Order is preserved from the
/// provider (which has already ranked); we just split at kind boundaries so
/// headers appear above each group's first row.
private struct URLSuggestionsDropdown: View {
    @Environment(BrowserViewModel.self) private var browser
    let suggestions: [URLSuggestion]
    @State private var hoveredID: UUID?

    private struct Section: Identifiable {
        let id = UUID()
        let kind: URLSuggestion.Kind
        let header: String?
        let rows: [URLSuggestion]
    }

    /// Split a flat list (already ranked) into ordered sections by kind.
    /// Top Hit gets no header (it's the special leading row); the others
    /// get a small uppercased label.
    private var sections: [Section] {
        var out: [Section] = []
        var buffer: [URLSuggestion] = []
        var currentKind: URLSuggestion.Kind?

        func flush() {
            guard let k = currentKind, !buffer.isEmpty else { return }
            out.append(Section(kind: k,
                                header: headerLabel(for: k),
                                rows: buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for s in suggestions {
            if currentKind == nil { currentKind = s.kind }
            if s.kind != currentKind {
                flush()
                currentKind = s.kind
            }
            buffer.append(s)
        }
        flush()
        return out
    }

    private func headerLabel(for kind: URLSuggestion.Kind) -> String? {
        switch kind {
        case .topHit:   return nil              // top hit has no header — it's the lead
        case .history:  return "History"
        case .bookmark: return "Bookmarks"
        case .search:   return "Search"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sections) { section in
                if let header = section.header {
                    Text(header)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                }
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { idx, suggestion in
                    row(suggestion)
                    if idx < section.rows.count - 1 {
                        Divider().padding(.leading, 32)
                    }
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 14, y: 4)
        .frame(maxWidth: 560)
    }

    private func row(_ s: URLSuggestion) -> some View {
        HStack(spacing: 10) {
            ZStack {
                if case .topHit = s.kind {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Color.accentColor)
                } else {
                    Image(systemName: s.symbol).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 13))
            .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(s.title)
                    .font(.system(size: 13, weight: s.kind == .topHit ? .semibold : .regular))
                    .lineLimit(1)
                Text(s.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            (hoveredID == s.id ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredID = hovering ? s.id : nil
            // Drive the status-bar overlay off suggestion hover (closest analog to a
            // real link hover in this clone).
            browser.hoveredLink = hovering ? s.subtitle : nil
        }
    }
}
