#include "color/OklchColor.h"

#include <algorithm>
#include <cmath>

namespace webkitium::color {
namespace {

constexpr double kPi = 3.14159265358979323846;

double SrgbChannelToLinear(double u) {
  return (u <= 0.04045) ? (u / 12.92)
                        : std::pow((u + 0.055) / 1.055, 2.4);
}

double LinearChannelToSrgb(double u) {
  return (u <= 0.0031308) ? (u * 12.92)
                          : (1.055 * std::pow(u, 1.0 / 2.4) - 0.055);
}

uint8_t Quantize8(double v) {
  const double clamped = std::clamp(v, 0.0, 1.0);
  return static_cast<uint8_t>(std::lround(clamped * 255.0));
}

}  // namespace

LinearSrgb SrgbToLinear(Srgb c) {
  return { SrgbChannelToLinear(c.r / 255.0),
           SrgbChannelToLinear(c.g / 255.0),
           SrgbChannelToLinear(c.b / 255.0) };
}

Srgb LinearToSrgb(LinearSrgb c) {
  return { Quantize8(LinearChannelToSrgb(c.r)),
           Quantize8(LinearChannelToSrgb(c.g)),
           Quantize8(LinearChannelToSrgb(c.b)) };
}

// Björn Ottosson, "A perceptual color space for image processing", 2020.
Oklab LinearToOklab(LinearSrgb c) {
  const double l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
  const double m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
  const double s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;

  const double l_ = std::cbrt(l);
  const double m_ = std::cbrt(m);
  const double s_ = std::cbrt(s);

  return { 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
           1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
           0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_ };
}

LinearSrgb OklabToLinear(Oklab c) {
  const double l_ = c.L + 0.3963377774 * c.a + 0.2158037573 * c.b;
  const double m_ = c.L - 0.1055613458 * c.a - 0.0638541728 * c.b;
  const double s_ = c.L - 0.0894841775 * c.a - 1.2914855480 * c.b;

  const double l = l_ * l_ * l_;
  const double m = m_ * m_ * m_;
  const double s = s_ * s_ * s_;

  return { +4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
           -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
           -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s };
}

Oklch OklabToOklch(Oklab c) {
  const double C = std::sqrt(c.a * c.a + c.b * c.b);
  double h = std::atan2(c.b, c.a) * 180.0 / kPi;
  if (h < 0.0) h += 360.0;
  if (C < 1e-9) h = 0.0;  // hue is meaningless at the achromatic axis
  return { c.L, C, h };
}

Oklab OklchToOklab(Oklch c) {
  const double rad = c.h_deg * kPi / 180.0;
  return { c.L, c.C * std::cos(rad), c.C * std::sin(rad) };
}

Oklch FromSrgb(Srgb c) {
  return OklabToOklch(LinearToOklab(SrgbToLinear(c)));
}

Srgb ToSrgb(Oklch c, bool clip_to_gamut) {
  Oklch out = clip_to_gamut ? GamutClipPreserveChroma(c) : c;
  return LinearToSrgb(OklabToLinear(OklchToOklab(out)));
}

bool IsInSrgbGamut(Oklab c) {
  const LinearSrgb linear = OklabToLinear(c);
  // Allow a tiny tolerance for floating-point noise at the gamut boundary.
  constexpr double kEps = 1e-6;
  return linear.r >= -kEps && linear.r <= 1.0 + kEps &&
         linear.g >= -kEps && linear.g <= 1.0 + kEps &&
         linear.b >= -kEps && linear.b <= 1.0 + kEps;
}

// Binary search for the largest chroma in [0, C] that is in-gamut at the
// requested (L, h). Converges in <25 iterations for 1e-5 precision.
Oklch GamutClipPreserveChroma(Oklch c) {
  if (c.C <= 0.0) return c;
  if (IsInSrgbGamut(OklchToOklab(c))) return c;

  double lo = 0.0;
  double hi = c.C;
  for (int i = 0; i < 32; ++i) {
    const double mid = 0.5 * (lo + hi);
    Oklch test = { c.L, mid, c.h_deg };
    if (IsInSrgbGamut(OklchToOklab(test))) {
      lo = mid;
    } else {
      hi = mid;
    }
    if ((hi - lo) < 1e-5) break;
  }
  return { c.L, lo, c.h_deg };
}

}  // namespace webkitium::color
