// Appearance-aware color lookup.
//
// Views read semantic colors via `\.semantic(.surfaceChrome)` rather
// than touching the palette directly. The helper resolves against
// whichever appearance SwiftUI is currently rendering in and triggers
// a re-render when the provider publishes a new seed.

import SwiftUI

struct SemanticColor: View {
    let token: SemanticToken

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var palette: PaletteProvider

    private var resolved: Color {
        colorScheme == .dark ? palette.dark[token] : palette.light[token]
    }

    var body: some View {
        resolved
    }
}

// View extension so callsites read cleanly: `.foregroundStyle(palette.semantic(.textPrimary))`
extension PaletteProvider {
    @MainActor
    func semantic(_ token: SemanticToken,
                  colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? dark[token] : light[token]
    }
}

// A small helper that takes both the provider and the current scheme,
// for use in `.background` / `.foregroundStyle` modifiers where a
// raw Color is needed. Pattern:
//
//     .background(ThemeBrush(.surfaceChrome))
//
struct ThemeBrush: ShapeStyle, View {
    let token: SemanticToken

    init(_ token: SemanticToken) { self.token = token }

    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var palette: PaletteProvider

    var body: some View {
        palette.semantic(token, colorScheme: colorScheme)
    }
}
