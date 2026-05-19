import SwiftUI

struct WebContentArea: View {
    let host: TabEngineHost

    var body: some View {
        ZStack {
            if PinnedEnginePaths.inProcessEmbedAvailable {
                PinnedEngineWebView(tabID: host.tabID, host: host)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !PinnedEnginePaths.inProcessEmbedAvailable {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Text("Pinned WebKit engine")
                .font(.headline)
            Text(host.displayURL.isEmpty ? "about:blank" : host.displayURL)
                .font(.body)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
            Text("Embed WebKit.framework from your iOS WebKit build into Webkitium.app/Frameworks.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
