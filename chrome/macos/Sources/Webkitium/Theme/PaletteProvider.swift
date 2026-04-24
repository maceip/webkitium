// Runtime palette applier for the macOS shell.
//
// Equivalent to chrome/windows/src/PaletteProvider.{h,cpp} in intent:
// given a brand seed (ARGB), call the shared C bridge to resolve the
// 22 semantic tokens twice (once per appearance), publish the two
// dictionaries, and let SwiftUI re-render every bound view.

import Foundation
import SwiftUI
import WebkitiumColor

// Index-into-semantic-palette enum that mirrors the C header's stable
// ordering. If browser/color/SemanticPalette.h reorders, this must too
// -- both are kept in lockstep by the kSemanticTokenNames assertion in
// the C bridge's test.
enum SemanticToken: Int, CaseIterable {
    case surfaceCanvas = 0
    case surfaceChrome
    case surfaceChromeRaised
    case surfaceSunken
    case surfaceHover
    case surfacePressed
    case surfaceOverlay
    case surfaceSelected
    case textPrimary
    case textSecondary
    case textTertiary
    case textOnBrand
    case textLink
    case borderSubtle
    case borderDefault
    case borderStrong
    case borderFocus
    case accentFill
    case accentFillHover
    case accentFillPressed
    case accentFillSubtle
    case textDanger
}

struct SemanticPalette {
    // Indexed by SemanticToken.rawValue. 22 slots.
    var colors: [Color] = Array(repeating: .clear,
                                count: Int(WK_SEMANTIC_TOKEN_COUNT))

    subscript(token: SemanticToken) -> Color {
        colors[token.rawValue]
    }

    static func resolve(seedArgb: UInt32, dark: Bool) -> SemanticPalette {
        var raw = [UInt32](repeating: 0, count: Int(WK_SEMANTIC_TOKEN_COUNT))
        let ok = raw.withUnsafeMutableBufferPointer { buf in
            wk_palette_resolve_semantic(seedArgb, dark ? 1 : 0,
                                        buf.baseAddress)
        }
        guard ok == 1 else { return SemanticPalette() }

        var out = SemanticPalette()
        out.colors = raw.map { argb in
            Color(
                red:   Double((argb >> 16) & 0xFF) / 255.0,
                green: Double((argb >> 8)  & 0xFF) / 255.0,
                blue:  Double((argb >> 0)  & 0xFF) / 255.0
            )
        }
        return out
    }
}

// ObservableObject because SwiftUI's re-render graph follows @Published
// changes. Any view reading `light` or `dark` re-renders on seed change.
@MainActor
final class PaletteProvider: ObservableObject {

    @Published private(set) var seedArgb: UInt32 = UInt32(WK_DEFAULT_BRAND_SEED_ARGB)
    @Published private(set) var light: SemanticPalette = .init()
    @Published private(set) var dark:  SemanticPalette = .init()

    private static let devSeedCycle: [UInt32] = [
        UInt32(WK_DEFAULT_BRAND_SEED_ARGB),  // webkitium blue
        0xFFD21F6B,                          // deep magenta
        0xFF2D7A3E,                          // forest green
        0xFF454B55,                          // near-monochrome
    ]
    private var devSeedIndex = 0

    init() {
        applySeed(UInt32(WK_DEFAULT_BRAND_SEED_ARGB))
    }

    func applySeed(_ argb: UInt32) {
        seedArgb = argb
        light = SemanticPalette.resolve(seedArgb: argb, dark: false)
        dark  = SemanticPalette.resolve(seedArgb: argb, dark: true)
    }

    /// Dev-only. Removed once the Settings → Appearance → Theme surface
    /// is live.
    func cycleDevSeed() {
        devSeedIndex = (devSeedIndex + 1) % Self.devSeedCycle.count
        applySeed(Self.devSeedCycle[devSeedIndex])
    }
}
