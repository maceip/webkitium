import SwiftUI

/// The puzzle-piece toolbar button + its popover content. Clicking opens a panel listing
/// installed extensions with per-extension toggle, plus footer links to Settings and the
/// integrated Store.
struct ExtensionsToolbarButton: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var browserBinding = browser
        Button {
            browser.showExtensionsPopover.toggle()
        } label: {
            Image(systemName: "puzzlepiece.extension")
        }
        .popover(isPresented: $browserBinding.showExtensionsPopover, arrowEdge: .bottom) {
            ExtensionsPopover(
                onManage: { openSettings(target: .extensions) },
                onStore:  { openSettings(target: .extensionsStore) })
                .frame(width: 320)
        }
        .contextMenu {
            Button("Manage Extensions…") { openSettings(target: .extensions) }
            Button("More Extensions in Store…") { openSettings(target: .extensionsStore) }
            Divider()
            Button("Hide Extensions Button") { /* hook to per-user preference */ }
        }
    }

    private func openSettings(target: SettingsTarget) {
        NotificationCenter.default.post(name: .openSettingsTarget,
                                        object: nil, userInfo: ["target": target])
        openWindow(id: "settings")
        browser.showExtensionsPopover = false
    }
}

/// The popover content — header + rows of installed extensions + manage/store footer.
struct ExtensionsPopover: View {
    let onManage: () -> Void
    let onStore: () -> Void
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(alignment: .leading, spacing: 8) {
            Text("Extensions")
                .font(.system(size: 13, weight: .semibold))
            Divider()
            ForEach($browserBinding.installedExtensions) { $ext in
                HStack(spacing: 8) {
                    ExtensionIcon(ext: ext, size: 22)
                    Text(ext.name).font(.system(size: 12))
                    Spacer(minLength: 0)
                    Toggle("", isOn: $ext.isEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                .frame(height: 28)
            }
            Divider()
            Button("Manage Extensions…", action: onManage)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
            Button("More Extensions in Store…", action: onStore)
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
        }
        .padding(12)
    }
}
