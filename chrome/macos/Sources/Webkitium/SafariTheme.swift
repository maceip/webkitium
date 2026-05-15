import SwiftUI

/// System theme — Safari's chrome is the standard macOS Liquid Glass material, not a
/// custom wine/pink color. The pink seen in reference screenshots was a translucent
/// material picking up the wallpaper / window behind the capture. The accent values are
/// kept only for the "selected" highlight in the sidebar (which DOES use the system
/// accent color via `Color.accentColor` everywhere it appears).
enum SafariTheme {
    /// Sidebar row selection pill — uses the system accent color at low opacity to match
    /// Safari's selection highlight on the active tab row.
    static let selectionAccent = Color.accentColor.opacity(0.22)
    /// Outline border for the sidebar's "N Tabs" header pill — also system accent.
    static let pillBorder = Color.accentColor.opacity(0.55)
}
