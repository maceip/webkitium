import SwiftUI

/// Tab content: pinned in-process `WKWebView` when frameworks are available;
/// otherwise placeholder + external MiniBrowser (`PinnedEngineLaunch`).
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
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Text("Pinned WebKit engine")
                .font(.headline)
            Text(host.displayURL.isEmpty ? "about:blank" : host.displayURL)
                .font(.body)
                .textSelection(.enabled)
                .lineLimit(3)
                .frame(maxWidth: .infinity)
            Text("Set WEBKIT_FRAMEWORK_PATH to your WebKit build, or use WEBKIT_MINIBROWSER for MiniBrowser.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
