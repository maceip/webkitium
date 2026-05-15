import SwiftUI

/// "Add to Dock" popover (macOS Sonoma+ Web App flow). Lets the user preview the icon
/// + name and confirm adding the current page as a standalone Web App to the Dock.
struct AddToDockPopover: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var appName: String = ""
    @State private var url: String = ""

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                appIcon
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $appName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                    TextField("URL", text: $url)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Text("This page will be added to the Dock and Applications folder. It will open in its own window with simplified controls.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear {
            appName = browser.selectedTab?.title ?? "Page"
            url = browser.urlText.isEmpty ? "https://www.apple.com" : browser.urlText
        }
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.gradient)
                .frame(width: 56, height: 56)
            (browser.selectedTab?.favicon ?? .generic(symbol: "globe"))
                .view(size: 28)
        }
        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }
}
