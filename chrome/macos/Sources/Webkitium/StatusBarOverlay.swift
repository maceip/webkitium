import SwiftUI

/// Safari's hover-URL status bar. Sits at the bottom-leading corner of the content pane
/// and fades in when a link is hovered. We use a tiny dedicated overlay rather than the
/// system status bar so we can match Safari's exact appearance: a rounded pill on
/// `.thinMaterial`, monospaced URL, fade in/out on hover changes.
struct StatusBarOverlay: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        if let link = browser.hoveredLink, !link.isEmpty {
            Text(link)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(.thinMaterial,
                             in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
                .padding(.leading, 8).padding(.bottom, 8)
                .transition(.opacity)
        }
    }
}
