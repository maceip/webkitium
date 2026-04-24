// OKLCH color math — ported from Björn Ottosson's public-domain reference
// (https://bottosson.github.io/posts/oklab/,
//  https://bottosson.github.io/posts/gamutclipping/).
//
// No Google / Material Color Utilities dependency. No HCT. This file owns
// the full conversion pipeline sRGB ↔ Linear sRGB ↔ Oklab ↔ OKLCH and the
// gamut-clipping strategy used when algorithmically-generated palettes
// overshoot displayable sRGB.

#pragma once

#include <array>
#include <cstdint>

namespace webkitium::color {

// 8-bit per-channel sRGB in the conventional range [0, 255].
struct Srgb {
  uint8_t r = 0;
  uint8_t g = 0;
  uint8_t b = 0;

  constexpr uint32_t ToArgb(uint8_t alpha = 0xFF) const {
    return (static_cast<uint32_t>(alpha) << 24) |
           (static_cast<uint32_t>(r)     << 16) |
           (static_cast<uint32_t>(g)     << 8)  |
           (static_cast<uint32_t>(b)     << 0);
  }

  static constexpr Srgb FromArgb(uint32_t argb) {
    return { static_cast<uint8_t>((argb >> 16) & 0xFF),
             static_cast<uint8_t>((argb >> 8)  & 0xFF),
             static_cast<uint8_t>((argb >> 0)  & 0xFF) };
  }
};

// Linear-light sRGB, each channel in [0, 1]. Values outside the range mean
// the color is out of the displayable sRGB gamut (common after generating a
// saturated palette).
struct LinearSrgb {
  double r = 0.0;
  double g = 0.0;
  double b = 0.0;
};

// Oklab. L is perceptual lightness in [0, 1] for displayable colors; a and b
// are opponent-color coordinates roughly in [-0.4, +0.4].
struct Oklab {
  double L = 0.0;
  double a = 0.0;
  double b = 0.0;
};

// Cylindrical form of Oklab. L = lightness, C = chroma (≥ 0), h_deg = hue
// in degrees (canonicalized to [0, 360)).
struct Oklch {
  double L = 0.0;
  double C = 0.0;
  double h_deg = 0.0;
};

// ---- Conversions --------------------------------------------------------

LinearSrgb SrgbToLinear(Srgb);
Srgb       LinearToSrgb(LinearSrgb);  // clamps channels into [0, 255]
Oklab      LinearToOklab(LinearSrgb);
LinearSrgb OklabToLinear(Oklab);
Oklch      OklabToOklch(Oklab);
Oklab      OklchToOklab(Oklch);

// Convenience round-trips through sRGB.
Oklch FromSrgb(Srgb);
Srgb  ToSrgb(Oklch, bool clip_to_gamut = true);

// ---- Gamut clipping -----------------------------------------------------

// True iff the color, rendered as Oklab, converts cleanly to LinearSrgb
// within [0, 1] on all channels.
bool IsInSrgbGamut(Oklab);

// Reduce chroma toward zero along the constant-L,constant-h line until the
// result is in-gamut. Preserves lightness and hue exactly. This is the
// strategy we use by default because it matches the user's perception of
// "the same color, less saturated."
Oklch GamutClipPreserveChroma(Oklch);

}  // namespace webkitium::color
