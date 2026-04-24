# Color ramp — algorithm and rationale

This document explains *what* the webkitium color ramp produces and *why* we chose the specific tone ladder and chroma curve it uses. The code lives in `browser/color/`.

## One algorithm, two jobs

1. **At runtime**, when a user writes `color.brand` via `browser.theme.set()`, each platform shell calls `GeneratePalette(seed)` to derive a full light + dark palette. The user sees the same brand palette on every device in their account.
2. **At build time**, the same function runs once with webkitium's shipped default seed. The output is committed into each platform's `Tokens` resource (`chrome/windows/src/Tokens.xaml`, later the equivalents on macOS/iOS/Android/Linux).

Because both paths run the same code, a user who "resets to default" and a user who explicitly sets their brand to webkitium's shipped hex value end up with **bit-identical palettes**. No drift.

## No Material You, no HCT

The math is pure OKLCH (CSS Color 4 / W3C). There is no dependency on Material Color Utilities, no HCT color space, no `TonalPalette`, no `DynamicScheme`, no `MaterialDynamicColors`. See `browser/color/README.md` for the rationale.

Material 3 and Material 3 Expressive palettes cap chroma around C≈48 to preserve accessibility across all possible backgrounds. That ceiling is why Material palettes feel pastel. We reject the ceiling. Our chroma curve peaks at the brand-primary tone and relies on the runtime contrast guard (`ERR_CONTRAST_VIOLATION`) to catch accessibility violations per-token pairing, rather than softening the entire palette.

## The tone ladder

Twelve perceptual lightness steps in OKLCH L (same scale as CSS `oklch()`). Semantic meaning follows the Radix 12-step convention.

| Step | Role | L (light) | L (dark) |
|---|---|---|---|
| 1 | App canvas background | 0.995 | 0.145 |
| 2 | Subtle background | 0.975 | 0.185 |
| 3 | UI element background | 0.945 | 0.235 |
| 4 | Hovered UI background | 0.905 | 0.290 |
| 5 | Active/selected UI bg | 0.855 | 0.355 |
| 6 | Subtle borders / separators | 0.785 | 0.430 |
| 7 | UI element borders / focus | 0.700 | 0.510 |
| 8 | Hovered UI borders | 0.610 | 0.585 |
| 9 | Solid brand fill | 0.540 | 0.640 |
| 10 | Hovered solid fill | 0.475 | 0.690 |
| 11 | Low-contrast text | 0.395 | 0.780 |
| 12 | High-contrast text | 0.220 | 0.955 |

**Why stretched at the extremes**: the light canvas is nearly paper-white (L=0.995 ≈ #FDFDFE) and the high-contrast text is deep enough that text on canvas exceeds WCAG AA (≈ 12:1 contrast). Material's default tones compress this range to stay safer across unrelated background colors; we target our specific layering so we can be more dramatic.

**Why dark is not an inversion**: dark tones 1–5 are compressed (0.145 → 0.355, a 0.21 span) while light tones 1–5 are stretched (0.855 → 0.995, a 0.14 span inverted). Human vision compresses perceived contrast on dark backgrounds, so equal-spacing would feel flat in dark mode. The compression puts more steps in the zone users actually notice.

## The chroma curve

Each step multiplies the seed's chroma by a curve value:

| Step | Light | Dark |
|---|---|---|
| 1 | 0.10× | 0.55× |
| 2 | 0.20× | 0.80× |
| 3 | 0.40× | 0.95× |
| 4 | 0.65× | 1.05× |
| 5 | 0.85× | 1.15× |
| 6 | 1.00× | 1.20× |
| 7 | 1.10× | 1.20× |
| 8 | 1.15× | 1.15× |
| 9 | 1.20× | 1.10× |
| 10 | 1.15× | 1.00× |
| 11 | 0.95× | 0.70× |
| 12 | 0.55× | 0.20× |

**Why peak ≈ step 9**: the brand "fill" is where users recognize the brand color most clearly. Boosting chroma at step 9 (and gently around it) makes the brand feel present without bleeding into backgrounds.

**Why taper at extremes**: step 1 tinted too heavily makes the canvas feel colored (not neutral-with-hint); step 12 tinted too heavily makes body text look colored. Both read as amateur.

**Why dark-mode boost at mid-range**: dark backgrounds absorb perceived saturation. A chroma value that looks vivid on a white surface looks muted on a black one; we compensate.

**Why >1.0× is allowed**: we can exceed the seed's own chroma because OKLCH lets us step out of the seed's "shell" if the user picked a desaturated seed. Gamut clipping (`GamutClipPreserveChroma` in `OklchColor.cpp`) pulls any overshoot back to the nearest valid sRGB color while preserving hue and lightness.

## Hue behavior

Hue is preserved exactly across all twelve steps of a ramp. Unlike some Material schemes, we do **not** drift hue between tones (warmer darks, cooler lights, etc.) — this would help visual cohesion in paper-inspired design but works against user expectation when the user chose a specific brand color. If the user picks magenta, every step is magenta-hued.

The one exception: at very low chroma (C < 0.01, near the achromatic axis) the hue angle is mathematically meaningless. `FromSrgb()` returns h=0 in that case; the ramp output is effectively grayscale.

## Neutral ramp

The neutral ramp uses the same tone ladder and a seed derived from the brand:

```cpp
neutral_seed = Oklch{ brand.L, 0.012, brand.h_deg }
```

Fixed tiny chroma (0.012) — enough to slightly warm/cool the grays toward the brand hue, not enough to read as tinted. A magenta-brand user sees faintly warm grays; a cyan-brand user sees faintly cool grays; the chrome feels *coordinated* with the brand without competing.

## Accessibility

Contrast is **not** enforced by making the palette conservative. It is enforced by the runtime contrast guard in the extension API — `browser.theme.set()` rejects writes that produce WCAG AA violations on the semantic pairings (`text.primary` on `surface.chrome`, `text.onBrand` on `accent.fill`, etc.) with `ERR_CONTRAST_VIOLATION`.

This means the ramp algorithm can be aggressive. If a particular user's particular brand color produces a palette that violates AA on some specific pairing, the guard tells them so and either the algorithm clips chroma further (via `GamutClipPreserveChroma`) or the extension presents the user with an alternative.

## Shipped default palette

`browser/color/ColorRamp.h` declares `kDefaultBrandSeed = {0x1F, 0x5A, 0xE0}` — webkitium blue. The palette it produces is committed into `chrome/<platform>/src/Tokens.xaml` (or equivalent) at first-run seed time.

```
brand_light: step 9  #0F58FF  (webkitium brand fill)
brand_dark:  step 9  #4B84FF
neutral_light step 12 #191B1E  (near-black text)
neutral_dark  step 12 #EFF0F2  (near-white text)
```

The full shipped table is in `chrome/windows/src/Tokens.xaml` (the reference implementation) and re-produced by the algorithm on any platform.

## Tuning levers (future)

The curve constants in `browser/color/ColorRamp.cpp` (`kTonesLight`, `kTonesDark`, `kChromaCurveLight`, `kChromaCurveDark`) are the only tuning surface. Changing them regenerates every shipped and user palette consistently — any change there is a user-visible palette change and requires a design review plus a contrast-guard pass across the semantic pairings.

## Things we deliberately do NOT expose

- Per-user control of tones or chroma curves. Users pick a brand color; the algorithm owns everything else.
- Per-token color overrides that bypass the ramp. Users change brand, and 24 generated colors follow. No "let me set step 7 to this specific color" surface.
- Secondary and tertiary brand colors. One brand color, one hue. Multi-hue palettes are out of scope and harder to produce consistently; we'd add them only if user research surfaces genuine demand.
