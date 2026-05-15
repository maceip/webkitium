import SwiftUI

/// The "aA" / Page Settings menu — macOS-equivalent of the iOS Safari Format menu.
/// Lives as a small popover from the URL field's trailing edge with: zoom buttons,
/// request desktop site, hide/show toolbar, and a "Website Settings…" deep link into the
/// per-site permissions sheet.
struct PageSettingsButton: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        Button { browser.showPageSettingsMenu.toggle() } label: {
            Image(systemName: "textformat.size")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Page Settings")
        .popover(isPresented: $browserBinding.showPageSettingsMenu, arrowEdge: .bottom) {
            PageSettingsPopover()
        }
    }
}

private struct PageSettingsPopover: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var requestDesktopSite = false
    @State private var hideToolbar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            zoomCluster
            Divider()
            Toggle("Request Desktop Website", isOn: $requestDesktopSite)
            Toggle("Hide Toolbar", isOn: $hideToolbar)
            Divider()
            Button {
                browser.showPageSettingsMenu = false
                browser.showSiteSettingsSheet = true
            } label: {
                Label("Website Settings…", systemImage: "switch.2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        }
        .padding(12)
        .frame(width: 240)
    }

    private var zoomCluster: some View {
        HStack(spacing: 0) {
            Button { browser.zoomOut() } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 36, height: 28)
            }
            .buttonStyle(.borderless)

            Divider().frame(width: 1, height: 16)

            Text("\(Int((browser.zoomLevel * 100).rounded()))%")
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)

            Divider().frame(width: 1, height: 16)

            Button { browser.zoomIn() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 36, height: 28)
            }
            .buttonStyle(.borderless)
        }
        .background(.thinMaterial,
                     in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
