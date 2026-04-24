#include "color/SemanticPalette.h"

namespace webkitium::color {
namespace {

// Mirrors design/tokens/semantic/light.tokens.json exactly. If you change
// a mapping here, change the JSON file too -- the design system is the
// canonical source and any drift is a bug.
constexpr int kLightIndex[kSemanticTokenCount][2] = {
    // { 0 = brand ramp, 1 = neutral ramp, 2 = status (not ramped) },
    // ramp index (0..11) or -1 if status
    /* SurfaceCanvas       */ {1, 0},
    /* SurfaceChrome       */ {1, 1},
    /* SurfaceChromeRaised */ {1, 0},
    /* SurfaceSunken       */ {1, 2},
    /* SurfaceHover        */ {1, 3},
    /* SurfacePressed      */ {1, 4},
    /* SurfaceOverlay      */ {1, 0},
    /* SurfaceSelected     */ {0, 3},
    /* TextPrimary         */ {1, 11},
    /* TextSecondary       */ {1, 10},
    /* TextTertiary        */ {1, 8},
    /* TextOnBrand         */ {1, 0},
    /* TextLink            */ {0, 10},
    /* BorderSubtle        */ {1, 4},
    /* BorderDefault       */ {1, 5},
    /* BorderStrong        */ {1, 7},
    /* BorderFocus         */ {0, 7},
    /* AccentFill          */ {0, 8},
    /* AccentFillHover     */ {0, 9},
    /* AccentFillPressed   */ {0, 10},
    /* AccentFillSubtle    */ {0, 2},
    /* TextDanger          */ {2, -1},
};

constexpr int kDarkIndex[kSemanticTokenCount][2] = {
    /* SurfaceCanvas       */ {1, 11},
    /* SurfaceChrome       */ {1, 10},
    /* SurfaceChromeRaised */ {1, 9},
    /* SurfaceSunken       */ {1, 11},
    /* SurfaceHover        */ {1, 8},
    /* SurfacePressed      */ {1, 7},
    /* SurfaceOverlay      */ {1, 9},
    /* SurfaceSelected     */ {0, 7},
    /* TextPrimary         */ {1, 0},
    /* TextSecondary       */ {1, 2},
    /* TextTertiary        */ {1, 5},
    /* TextOnBrand         */ {1, 11},
    /* TextLink            */ {0, 5},
    /* BorderSubtle        */ {1, 9},
    /* BorderDefault       */ {1, 8},
    /* BorderStrong        */ {1, 6},
    /* BorderFocus         */ {0, 6},
    /* AccentFill          */ {0, 8},
    /* AccentFillHover     */ {0, 7},
    /* AccentFillPressed   */ {0, 6},
    /* AccentFillSubtle    */ {0, 10},
    /* TextDanger          */ {2, -1},
};

// #D83A2D -- matches design/tokens/base/color.tokens.json danger.9.
constexpr Srgb kDanger9{ 0xD8, 0x3A, 0x2D };

}  // namespace

SemanticPalette ResolveSemanticPalette(const Palette& palette, bool dark) {
    const auto& index = dark ? kDarkIndex : kLightIndex;
    const Ramp& brand   = dark ? palette.brand_dark   : palette.brand_light;
    const Ramp& neutral = dark ? palette.neutral_dark : palette.neutral_light;

    SemanticPalette out;
    for (int i = 0; i < kSemanticTokenCount; ++i) {
        const int ramp = index[i][0];
        const int step = index[i][1];
        if (ramp == 0) {
            out.colors[i] = brand[step];
        } else if (ramp == 1) {
            out.colors[i] = neutral[step];
        } else {
            out.colors[i] = kDanger9;
        }
    }
    return out;
}

}  // namespace webkitium::color
