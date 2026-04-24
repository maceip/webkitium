// Webkitium color ramp.
//
// Given a user brand color, produce a twelve-step light ramp and twelve-step
// dark ramp. Uses OKLCH math from OklchColor.h. No Material You layers, no
// Material tonal scheme, no Google-derived tone or chroma choices — the
// ladder and curve are ours and documented in design/color/RAMP.md.
//
// Twelve-step semantics (borrowed from Radix Colors):
//   1  App canvas background
//   2  Subtle background
//   3  UI element background
//   4  Hovered UI element background
//   5  Active / selected UI element background
//   6  Subtle borders and separators
//   7  UI element border and focus rings
//   8  Hovered UI element border
//   9  Solid backgrounds (brand "fill")
//   10 Hovered solid backgrounds
//   11 Low-contrast text
//   12 High-contrast text

#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

#include "color/OklchColor.h"

namespace webkitium::color {

// A single 12-step ramp.
struct Ramp {
  std::array<Srgb, 12> steps{};

  Srgb operator[](int index) const { return steps[static_cast<size_t>(index)]; }
};

// Full palette: brand and neutral ramps, both appearances.
struct Palette {
  Ramp brand_light;
  Ramp brand_dark;
  Ramp neutral_light;
  Ramp neutral_dark;
};

// Generate the complete palette from a single seed. The seed is the brand
// color as the user would pick it: a fully saturated sRGB value. The ramp
// algorithm preserves the seed's hue, scales chroma along our curve, and
// steps through our tone ladder. Out-of-gamut combinations are clipped with
// GamutClipPreserveChroma.
Palette GeneratePalette(Srgb brand_seed);

// Low-level building block exposed for tests and for callers that only
// need a single ramp (e.g. the webkitium default neutral).
Ramp GenerateRamp(Oklch seed, bool dark);

// The shipped webkitium default brand seed, in case a shell needs it at
// runtime (e.g. during first-run before sync settles).
constexpr Srgb kDefaultBrandSeed{ 0x1F, 0x5A, 0xE0 };  // webkitium blue

}  // namespace webkitium::color
