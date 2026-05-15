import SwiftUI

/// Safari's share popover — a custom popover anchored to the toolbar share button. Lists
/// the Safari-specific destinations (Reading List, Bookmarks, Email, Messages, Notes,
/// Reminders, AirDrop placeholder) plus a "More…" item that invokes the standard system
/// share sheet via `NSSharingServicePicker`.
struct ShareToolbarButton: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var showShare = false

    var body: some View {
        Button { showShare.toggle() } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.borderless)
        .help("Share")
        .popover(isPresented: $showShare, arrowEdge: .bottom) {
            SharePopover(
                title: browser.selectedTab?.title ?? "Page",
                url: URL(string: browser.urlText.isEmpty ? "https://example.com" : browser.urlText)
                  ?? URL(string: "https://example.com")!,
                onDismiss: { showShare = false })
        }
    }
}

struct SharePopover: View {
    let title: String
    let url: URL
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header — title + URL preview
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(url.host ?? url.absoluteString)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

            Divider()

            // Safari-specific destinations
            ShareRow(symbol: "book.closed",  title: "Add to Reading List") { dismissAfter() }
            ShareRow(symbol: "star",         title: "Add Bookmark…")        { dismissAfter() }
            Divider().padding(.leading, 44)
            ShareRow(symbol: "envelope",     title: "Email This Page")      { share(via: .composeEmail) }
            ShareRow(symbol: "message",      title: "Messages")             { share(via: .composeMessage) }
            ShareRow(symbol: "note.text",    title: "Notes")                { dismissAfter() }
            ShareRow(symbol: "list.bullet",  title: "Reminders")            { dismissAfter() }
            ShareRow(symbol: "wifi",         title: "AirDrop")              { share(via: nil, picker: true) }
            Divider().padding(.leading, 44)
            ShareRow(symbol: "ellipsis.circle", title: "More…")              { share(via: nil, picker: true) }
        }
        .padding(.bottom, 6)
        .frame(width: 280)
    }

    private func dismissAfter() {
        onDismiss()
    }

    /// Invoke the macOS system share sheet (NSSharingServicePicker) for any destinations
    /// that need it. Items are passed as a URL + plain-text title combo.
    private func share(via service: NSSharingService.Name?, picker: Bool = false) {
        let items: [Any] = [url, title]
        if picker {
            let picker = NSSharingServicePicker(items: items)
            if let window = NSApp.keyWindow,
               let contentView = window.contentView {
                picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
            }
        } else if let name = service,
                  let s = NSSharingService(named: name) {
            s.perform(withItems: items)
        }
        onDismiss()
    }
}

/// Single row in the share popover — icon + title, hover highlight.
private struct ShareRow: View {
    let symbol: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                Text(title).font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .frame(height: 30)
            .background(hovering ? Color.accentColor.opacity(0.18) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
