import SwiftUI

/// Renders one toolbar button per ENABLED extension whose manifest declared
/// `hasToolbarButton`. Matches the Chrome / Edge / Safari pattern: each
/// extension gets its own clickable icon at the leading edge of the right
/// toolbar cluster.
///
/// Source of truth is `ExtensionCatalog.installed` for now; a future change
/// will lift this into `BrowserViewModel` so toggling enable/disable from
/// the Manage Extensions pane propagates to the toolbar without a reload.
struct PerExtensionToolbarButtons: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var activeID: String?

    private var visible: [BrowserExtension] {
        browser.installedExtensions.filter { $0.isEnabled && $0.hasToolbarButton }
    }

    var body: some View {
        ForEach(visible) { ext in
            ExtensionToolbarTrigger(ext: ext,
                                     isActive: Binding(
                                        get: { activeID == ext.id },
                                        set: { activeID = $0 ? ext.id : nil }))
        }
    }
}

private struct ExtensionToolbarTrigger: View {
    let ext: BrowserExtension
    @Binding var isActive: Bool

    var body: some View {
        Button {
            isActive.toggle()
        } label: {
            ExtensionIcon(ext: ext, size: 18)
                .frame(width: 44, height: 42)
        }
        .buttonStyle(.borderless)
        .help(ext.name)
        .popover(isPresented: $isActive, arrowEdge: .bottom) {
            // Placeholder action popup — the real one is wired once
            // `browser/extensions/` exposes per-action HTML/JS hosts.
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    ExtensionIcon(ext: ext, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ext.name).font(.system(size: 13, weight: .semibold))
                        Text("Version \(ext.version)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(ext.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Divider()
                Text("This extension's action popup will appear here once the host runtime is wired through `browser/extensions/`.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(width: 280)
        }
    }
}
