import SwiftUI

/// Transient zoom HUD — a centered rounded pill showing the current zoom percentage.
/// Triggered when the user invokes Cmd+= / Cmd+- / Cmd+0. Auto-fades after ~1.2s via the
/// BrowserViewModel's dismiss task.
struct ZoomHUD: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        let pct = Int((browser.zoomLevel * 100).rounded())
        HStack(spacing: 10) {
            Image(systemName: pct == 100 ? "magnifyingglass" :
                                pct > 100 ? "plus.magnifyingglass" : "minus.magnifyingglass")
                .font(.system(size: 20, weight: .medium))
            Text("\(pct)%")
                .font(.system(size: 22, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 18, y: 6)
    }
}
