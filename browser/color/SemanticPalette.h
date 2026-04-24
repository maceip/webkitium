// Maps the generated Palette (four 12-step ramps) to the 22 semantic
// token names that every shell's resource dictionary consumes.
//
// The mapping matches design/tokens/semantic/{light,dark}.tokens.json
// exactly. Any change here requires the same change in those two files
// and in the design/README.md documentation -- the mapping is part of
// the cross-platform brand, not a per-platform choice.

#pragma once

#include <array>
#include <string_view>

#include "color/ColorRamp.h"

namespace webkitium::color {

// Stable ordering so callers can iterate and zip with string keys.
enum class SemanticToken : int {
    SurfaceCanvas = 0,
    SurfaceChrome,
    SurfaceChromeRaised,
    SurfaceSunken,
    SurfaceHover,
    SurfacePressed,
    SurfaceOverlay,
    SurfaceSelected,

    TextPrimary,
    TextSecondary,
    TextTertiary,
    TextOnBrand,
    TextLink,

    BorderSubtle,
    BorderDefault,
    BorderStrong,
    BorderFocus,

    AccentFill,
    AccentFillHover,
    AccentFillPressed,
    AccentFillSubtle,

    // text.danger and status colors are intentionally NOT ramped -- users
    // do not theme error/success/warning to match brand.
    TextDanger,

    kCount,
};

constexpr int kSemanticTokenCount = static_cast<int>(SemanticToken::kCount);

// The ThemeDictionaries key each platform uses under its own hood;
// identical across platforms so extension authors see consistent names.
// Indexed by SemanticToken.
inline constexpr std::array<std::string_view, kSemanticTokenCount> kSemanticTokenNames = {
    "SurfaceCanvas",
    "SurfaceChrome",
    "SurfaceChromeRaised",
    "SurfaceSunken",
    "SurfaceHover",
    "SurfacePressed",
    "SurfaceOverlay",
    "SurfaceSelected",
    "TextPrimary",
    "TextSecondary",
    "TextTertiary",
    "TextOnBrand",
    "TextLink",
    "BorderSubtle",
    "BorderDefault",
    "BorderStrong",
    "BorderFocus",
    "AccentFill",
    "AccentFillHover",
    "AccentFillPressed",
    "AccentFillSubtle",
    "TextDanger",
};

// Resolves the 22 semantic tokens for a single appearance (light or dark)
// by looking up the right step in the right ramp for each token. Returned
// in the order declared by SemanticToken, so callers can zip with
// kSemanticTokenNames.
struct SemanticPalette {
    std::array<Srgb, kSemanticTokenCount> colors{};

    Srgb operator[](SemanticToken t) const {
        return colors[static_cast<size_t>(t)];
    }
};

SemanticPalette ResolveSemanticPalette(const Palette&, bool dark);

}  // namespace webkitium::color
