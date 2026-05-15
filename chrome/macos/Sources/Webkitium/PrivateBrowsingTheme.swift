import SwiftUI

/// Visual treatment for Private Browsing mode. Safari darkens the entire window chrome
/// and adds a saturated dark-purple tint so the mode is instantly identifiable. We apply
/// the tint as a thin overlay on top of existing materials in three places — sidebar
/// container, detail container, and the window toolbar background — so the rest of the
/// chrome stays structurally identical to the regular window.
public enum PrivateBrowsingPalette {
    /// Base tint color — saturated dark purple, matches the iOS/macOS Safari Private hue.
    public static let base = Color(.sRGB,
                                    red:   0.12,
                                    green: 0.10,
                                    blue:  0.22,
                                    opacity: 1)

    /// Overlay tint applied to chrome surfaces (sidebar VStack, detail VStack) — strong
    /// enough to be unmistakable but still lets the system blur read through.
    public static let chromeOverlay = base.opacity(0.6)

    /// Toolbar-specific tint — used with `.toolbarBackground(_:for: .windowToolbar)`.
    public static let toolbarBackground = base.opacity(0.85)
}

extension View {
    /// Apply Safari's "Private Browsing" tint to the chrome row this view represents.
    /// Pass `isPrivate` to gate the modifier; no-op when off.
    func privateChromeTint(_ isPrivate: Bool) -> some View {
        modifier(PrivateChromeTint(isPrivate: isPrivate))
    }
}

private struct PrivateChromeTint: ViewModifier {
    let isPrivate: Bool
    func body(content: Content) -> some View {
        content.overlay(
            isPrivate ? AnyView(
                PrivateBrowsingPalette.chromeOverlay
                    .allowsHitTesting(false)
            ) : AnyView(EmptyView())
        )
    }
}

/// Small "Private" badge displayed at the top of the sidebar when the window is in
/// Private Browsing mode. Sized + styled to match Safari's actual badge.
struct PrivateModeBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 10, weight: .bold))
            Text("Private")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .foregroundStyle(.white)
        .background(
            Capsule().fill(PrivateBrowsingPalette.base)
        )
    }
}
