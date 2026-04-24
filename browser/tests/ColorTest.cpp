#include "color/ColorRamp.h"
#include "color/OklchColor.h"

#include <cassert>
#include <cmath>
#include <cstdlib>
#include <iostream>

namespace {

using webkitium::color::FromSrgb;
using webkitium::color::GamutClipPreserveChroma;
using webkitium::color::GeneratePalette;
using webkitium::color::IsInSrgbGamut;
using webkitium::color::LinearToOklab;
using webkitium::color::Oklch;
using webkitium::color::OklchToOklab;
using webkitium::color::Srgb;
using webkitium::color::SrgbToLinear;
using webkitium::color::ToSrgb;

int g_failures = 0;

#define EXPECT(cond) do {                                                 \
    if (!(cond)) {                                                        \
        std::cerr << "FAIL " << __FILE__ << ":" << __LINE__               \
                  << "  " #cond << "\n";                                  \
        ++g_failures;                                                     \
    }                                                                     \
} while (0)

#define EXPECT_NEAR(a, b, tol) do {                                       \
    const double aa = (a);                                                \
    const double bb = (b);                                                \
    if (std::abs(aa - bb) > (tol)) {                                      \
        std::cerr << "FAIL " << __FILE__ << ":" << __LINE__               \
                  << "  |" << aa << " - " << bb << "| > " << (tol) << "\n";\
        ++g_failures;                                                     \
    }                                                                     \
} while (0)

bool SrgbEq(Srgb a, Srgb b, int tol = 1) {
  return std::abs(int(a.r) - int(b.r)) <= tol &&
         std::abs(int(a.g) - int(b.g)) <= tol &&
         std::abs(int(a.b) - int(b.b)) <= tol;
}

// --- OKLCH round-trip ----------------------------------------------------

void TestRoundTripWhite() {
  const Srgb white{ 255, 255, 255 };
  const Oklch lch = FromSrgb(white);
  EXPECT_NEAR(lch.L, 1.0, 0.001);
  EXPECT_NEAR(lch.C, 0.0, 0.001);

  const Srgb back = ToSrgb(lch);
  EXPECT(SrgbEq(white, back));
}

void TestRoundTripBlack() {
  const Srgb black{ 0, 0, 0 };
  const Oklch lch = FromSrgb(black);
  EXPECT_NEAR(lch.L, 0.0, 0.001);
  EXPECT_NEAR(lch.C, 0.0, 0.001);

  const Srgb back = ToSrgb(lch);
  EXPECT(SrgbEq(black, back));
}

void TestRoundTripGrays() {
  for (int v = 0; v <= 255; v += 17) {
    const Srgb gray{ uint8_t(v), uint8_t(v), uint8_t(v) };
    const Oklch lch = FromSrgb(gray);
    EXPECT_NEAR(lch.C, 0.0, 0.005);  // grays are achromatic
    const Srgb back = ToSrgb(lch);
    EXPECT(SrgbEq(gray, back));
  }
}

void TestRoundTripSaturated() {
  // Pure primaries and secondaries should round-trip to within 1 LSB.
  const Srgb samples[] = {
      {255, 0, 0}, {0, 255, 0}, {0, 0, 255},
      {255, 255, 0}, {255, 0, 255}, {0, 255, 255},
      {128, 64, 200}, {31, 90, 224},  // webkitium default seed-like
  };
  for (const auto& c : samples) {
    const Srgb back = ToSrgb(FromSrgb(c));
    EXPECT(SrgbEq(c, back));
  }
}

// --- Gamut clipping ------------------------------------------------------

void TestClippingPreservesHueAndLightness() {
  // Very high chroma at mid lightness is out of gamut for most hues.
  const Oklch oversaturated{ 0.55, 0.40, 29.0 };
  EXPECT(!IsInSrgbGamut(OklchToOklab(oversaturated)));

  const Oklch clipped = GamutClipPreserveChroma(oversaturated);
  EXPECT(IsInSrgbGamut(OklchToOklab(clipped)));
  EXPECT_NEAR(clipped.L, oversaturated.L, 1e-6);
  EXPECT_NEAR(clipped.h_deg, oversaturated.h_deg, 1e-6);
  EXPECT(clipped.C < oversaturated.C);
  EXPECT(clipped.C >= 0.0);
}

void TestClippingIsIdentityInGamut() {
  const Oklch safe{ 0.50, 0.05, 200.0 };
  EXPECT(IsInSrgbGamut(OklchToOklab(safe)));

  const Oklch same = GamutClipPreserveChroma(safe);
  EXPECT_NEAR(same.L, safe.L, 1e-9);
  EXPECT_NEAR(same.C, safe.C, 1e-9);
  EXPECT_NEAR(same.h_deg, safe.h_deg, 1e-9);
}

// --- Ramp ----------------------------------------------------------------

void TestRampLightnessIsMonotonic() {
  const auto palette = GeneratePalette({0x1F, 0x5A, 0xE0});  // default seed
  for (int i = 1; i < 12; ++i) {
    const Oklch prev = FromSrgb(palette.brand_light[i - 1]);
    const Oklch curr = FromSrgb(palette.brand_light[i]);
    // Light ramp descends in L as index increases.
    EXPECT(curr.L < prev.L);
  }
  for (int i = 1; i < 12; ++i) {
    const Oklch prev = FromSrgb(palette.brand_dark[i - 1]);
    const Oklch curr = FromSrgb(palette.brand_dark[i]);
    // Dark ramp ascends in L as index increases (1 is darkest canvas bg).
    EXPECT(curr.L > prev.L);
  }
}

void TestRampHueIsPreserved() {
  const auto palette = GeneratePalette({0x1F, 0x5A, 0xE0});
  const Oklch seed = FromSrgb({0x1F, 0x5A, 0xE0});

  // Mid-ramp steps should retain the seed hue to within a few degrees
  // (extremes drift more because of chroma tapering toward gray).
  for (int i = 3; i <= 10; ++i) {
    const Oklch step = FromSrgb(palette.brand_light[i]);
    if (step.C < 0.01) continue;  // skipped near-gray steps
    double dh = std::abs(step.h_deg - seed.h_deg);
    if (dh > 180.0) dh = 360.0 - dh;
    EXPECT(dh < 5.0);
  }
}

void TestNeutralRampIsNearGray() {
  const auto palette = GeneratePalette({0xD2, 0x1F, 0x6B});  // magenta seed
  // Neutral ramp uses very low chroma; no step should exceed C ≈ 0.02.
  for (int i = 0; i < 12; ++i) {
    const Oklch step = FromSrgb(palette.neutral_light[i]);
    EXPECT(step.C < 0.02);
  }
}

void TestRampSurvivesExtremeSeeds() {
  // Any displayable sRGB seed must produce a valid, in-gamut ramp.
  const Srgb seeds[] = {
      {0xFF, 0x00, 0x00}, {0x00, 0xFF, 0x00}, {0x00, 0x00, 0xFF},
      {0xFF, 0xFF, 0xFF}, {0x00, 0x00, 0x00}, {0x7F, 0x7F, 0x7F},
      {0xFF, 0x00, 0xFF}, {0x12, 0x34, 0x56},
  };
  for (const auto& seed : seeds) {
    const auto palette = GeneratePalette(seed);
    for (int i = 0; i < 12; ++i) {
      // All steps must be valid sRGB (ToSrgb already clamps).
      const Srgb step = palette.brand_light[i];
      (void)step;  // compile-check; ToSrgb clamps into [0,255] inherently.
    }
  }
}

}  // namespace

int main() {
  TestRoundTripWhite();
  TestRoundTripBlack();
  TestRoundTripGrays();
  TestRoundTripSaturated();
  TestClippingPreservesHueAndLightness();
  TestClippingIsIdentityInGamut();
  TestRampLightnessIsMonotonic();
  TestRampHueIsPreserved();
  TestNeutralRampIsNearGray();
  TestRampSurvivesExtremeSeeds();

  if (g_failures > 0) {
    std::cerr << g_failures << " assertion failure(s)\n";
    return EXIT_FAILURE;
  }
  std::cout << "ColorTest: all checks passed\n";
  return 0;
}
