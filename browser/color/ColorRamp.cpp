#include "color/ColorRamp.h"

#include <algorithm>

namespace webkitium::color {
namespace {

// Our tone ladder. Twelve steps of perceptual lightness L, in OKLCH units
// (same scale as CSS Color 4 oklch()). Stretched more aggressively at the
// extremes than Material's default TonalSpot — step 1 is nearly paper-white,
// step 12 is deep enough for AA on step 1 text.
constexpr std::array<double, 12> kTonesLight = {
    0.995, 0.975, 0.945, 0.905, 0.855, 0.785,
    0.700, 0.610, 0.540, 0.475, 0.395, 0.220,
};

// Dark-mode tones are NOT a simple inversion. Human vision perceives
// less saturation on dark backgrounds, so tones are slightly compressed
// toward mid-lightness and the step-9 brand target is a touch lighter.
constexpr std::array<double, 12> kTonesDark = {
    0.145, 0.185, 0.235, 0.290, 0.355, 0.430,
    0.510, 0.585, 0.640, 0.690, 0.780, 0.955,
};

// Chroma curve. Peak at step 9 (the brand "fill"). Tapers near the
// extremes so white-ish and near-black steps don't read as tinted.
//
// Index i maps to a multiplier m_i applied to the seed's chroma. Seeds
// with low chroma (near-gray) produce near-gray ramps because m*0 = 0.
constexpr std::array<double, 12> kChromaCurveLight = {
    0.10, 0.20, 0.40, 0.65, 0.85, 1.00,
    1.10, 1.15, 1.20, 1.15, 0.95, 0.55,
};

// Dark mode gets slightly more chroma in the mid-range since dark
// backgrounds absorb perceived saturation.
constexpr std::array<double, 12> kChromaCurveDark = {
    0.55, 0.80, 0.95, 1.05, 1.15, 1.20,
    1.20, 1.15, 1.10, 1.00, 0.70, 0.20,
};

// Neutral seed used when a shell asks for the neutral ramp. Pulls a slight
// hue toward the brand so the chrome feels coordinated without being tinted.
Oklch NeutralSeedFromBrand(Oklch brand) {
  return Oklch{ brand.L, 0.012, brand.h_deg };
}

Ramp GenerateRampImpl(Oklch seed,
                      const std::array<double, 12>& tones,
                      const std::array<double, 12>& chroma_curve) {
  Ramp out{};
  for (int i = 0; i < 12; ++i) {
    Oklch step{ tones[i], seed.C * chroma_curve[i], seed.h_deg };
    out.steps[i] = ToSrgb(step, /*clip_to_gamut=*/true);
  }
  return out;
}

}  // namespace

Ramp GenerateRamp(Oklch seed, bool dark) {
  return GenerateRampImpl(seed,
                          dark ? kTonesDark : kTonesLight,
                          dark ? kChromaCurveDark : kChromaCurveLight);
}

Palette GeneratePalette(Srgb brand_seed) {
  const Oklch brand = FromSrgb(brand_seed);
  const Oklch neutral = NeutralSeedFromBrand(brand);

  return Palette{
      GenerateRamp(brand,   /*dark=*/false),
      GenerateRamp(brand,   /*dark=*/true),
      GenerateRamp(neutral, /*dark=*/false),
      GenerateRamp(neutral, /*dark=*/true),
  };
}

}  // namespace webkitium::color
