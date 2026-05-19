import SwiftUI

struct WebContentArea: View {
    let host: TabEngineHost

    var body: some View {
        VStack(spacing: 12) {
            Text("Pinned WebKit engine")
                .font(.headline)
            Text(host.displayURL.isEmpty ? "about:blank" : host.displayURL)
                .font(.body)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
            Text("Content runs in MiniBrowser from your WebKit build.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
