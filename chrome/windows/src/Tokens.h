// Webkitium design tokens as C++ constants — for code paths that can't
// reach the XAML ResourceDictionary (e.g., custom drawing, window-level
// setup before the app's resource tree is live).
//
// Values mirror Tokens.xaml and must stay in lockstep. Both are produced
// by browser/color/ColorRamp.cpp for kDefaultBrandSeed (#1F5AE0).
//
// Runtime palette updates (when the user changes their brand via
// browser.theme.set) rewrite the XAML ResourceDictionary in place; they
// do NOT mutate these constants — so consumers who need the live palette
// should read from the resource tree, not from here.

#pragma once

#include <cstdint>

namespace webkitium::chrome::windows::tokens {

// ---- Brand ramp (light) -------------------------------------------------
inline constexpr uint32_t kBrand1Light  = 0xFFFDFDFF;
inline constexpr uint32_t kBrand2Light  = 0xFFF3F7FF;
inline constexpr uint32_t kBrand3Light  = 0xFFE4EDFF;
inline constexpr uint32_t kBrand4Light  = 0xFFD0E0FF;
inline constexpr uint32_t kBrand5Light  = 0xFFB7D0FF;
inline constexpr uint32_t kBrand6Light  = 0xFF94B9FF;
inline constexpr uint32_t kBrand7Light  = 0xFF6A9BFF;
inline constexpr uint32_t kBrand8Light  = 0xFF3B78FF;
inline constexpr uint32_t kBrand9Light  = 0xFF0F58FF;
inline constexpr uint32_t kBrand10Light = 0xFF0044E1;
inline constexpr uint32_t kBrand11Light = 0xFF0033AF;
inline constexpr uint32_t kBrand12Light = 0xFF00114D;

// ---- Brand ramp (dark) --------------------------------------------------
inline constexpr uint32_t kBrand1Dark  = 0xFF000528;
inline constexpr uint32_t kBrand2Dark  = 0xFF000B3B;
inline constexpr uint32_t kBrand3Dark  = 0xFF001455;
inline constexpr uint32_t kBrand4Dark  = 0xFF001E73;
inline constexpr uint32_t kBrand5Dark  = 0xFF002B98;
inline constexpr uint32_t kBrand6Dark  = 0xFF003BC5;
inline constexpr uint32_t kBrand7Dark  = 0xFF034DF5;
inline constexpr uint32_t kBrand8Dark  = 0xFF2D6EFF;
inline constexpr uint32_t kBrand9Dark  = 0xFF4B84FF;
inline constexpr uint32_t kBrand10Dark = 0xFF6597FF;
inline constexpr uint32_t kBrand11Dark = 0xFF92B7FF;
inline constexpr uint32_t kBrand12Dark = 0xFFE9F0FF;

// ---- Neutral ramps (abbreviated — add as needed) -----------------------
inline constexpr uint32_t kNeutral1Light  = 0xFFFDFDFE;
inline constexpr uint32_t kNeutral12Light = 0xFF191B1E;
inline constexpr uint32_t kNeutral1Dark   = 0xFF090A0D;
inline constexpr uint32_t kNeutral12Dark  = 0xFFEFF0F2;

// ---- Shape --------------------------------------------------------------
inline constexpr double kRadiusOmnibar     = 10.0;
inline constexpr double kRadiusContextMenu = 8.0;
inline constexpr double kRadiusMd          = 10.0;

// ---- Spacing ------------------------------------------------------------
inline constexpr double kSpace1 = 4.0;
inline constexpr double kSpace2 = 8.0;
inline constexpr double kSpace3 = 12.0;
inline constexpr double kSpace4 = 16.0;

// ---- Motion -------------------------------------------------------------
inline constexpr double kDurationFastMs   = 120.0;
inline constexpr double kDurationMediumMs = 240.0;
inline constexpr double kDurationSlowMs   = 360.0;

}  // namespace webkitium::chrome::windows::tokens
