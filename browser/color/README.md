# `browser/color/`

Perceptual color math and palette generation. Portable C++, used by every platform shell at runtime and by the build pipeline to produce the shipped default palette.

## What lives here

| File | Purpose |
|---|---|
| `OklchColor.h` / `.cpp` | sRGB ↔ Linear sRGB ↔ Oklab ↔ OKLCH conversion. Ported from Björn Ottosson's public-domain reference (<https://bottosson.github.io/posts/oklab/>). |
| `ColorRamp.h` / `.cpp` | Given a user brand color, produce a 12-step light ramp + 12-step dark ramp using our own tone ladder and chroma curve. |

## What does NOT live here

- No Material Color Utilities. No HCT. No `TonalPalette`, no `DynamicScheme`, no `MaterialDynamicColors`.
- No aesthetic choices from Google or Material 3 / Material 3 Expressive.
- No Google dependency of any kind.

## Why OKLCH and not HCT

1. **OKLCH is the CSS Color 4 standard.** Our web-content renderer (WebKit) already speaks it natively.
2. **No Google dependency.** The math is public-domain, ~200 lines of matrix operations; we own it.
3. **Output quality is indistinguishable from HCT in practice** — both are perceptually-uniform color spaces derived from modern color appearance models.
4. **Industry standing**: OKLCH is in the W3C spec; HCT is a Google proprietary construction.

## Why our own curve and not Material's tone/chroma defaults

Material's `TonalSpot` scheme caps chroma around C≈48 for most hues so palettes remain legible across every possible background. That ceiling is exactly why Material palettes feel pastel and soft — "kindergarten palettes," as one internal reviewer put it.

We reject the ceiling. Our chroma curve peaks at the brand-primary tone for punchy brand presence and we rely on the **runtime contrast guard** in `browser/extensions/` (`ERR_CONTRAST_VIOLATION`) to catch any user theme that violates WCAG AA — rather than baking conservatism into the palette math.

See `design/color/RAMP.md` for the full rationale and the specific tone ladder + chroma curve.

## Two jobs, one codepath

- **Runtime**: when a user writes `color.brand` via `browser.theme.set()`, each shell calls `GenerateRamp(seed)` to derive the twelve-step ramp. Light and dark are produced together.
- **Build time**: the same function, same seed (webkitium's shipped default), pre-computed once and committed into each platform's `Tokens` resource. No drift between "factory default" and "user re-sets to the same seed."

There is no code path that produces a palette any other way. Hand-writing ramps is forbidden — it invites drift.

## Public API (stable)

```cpp
namespace webkitium::color {

struct Srgb { uint8_t r, g, b; };      // 8-bit per channel
struct Oklch { double L, C, h_deg; };  // L in [0,1], C ≥ 0, h in [0,360)

Oklch FromSrgb(Srgb);
Srgb  ToSrgb(Oklch, bool clip_to_gamut = true);

struct Ramp { std::array<Srgb, 12> steps; };
struct Palette {
  Ramp brand_light;
  Ramp brand_dark;
  Ramp neutral_light;
  Ramp neutral_dark;
};

Palette GeneratePalette(Srgb brand_seed);

}  // namespace webkitium::color
```

Everything else is an implementation detail.

## Testing

`browser/tests/OklchColorTest.cpp` — round-trip sRGB ↔ OKLCH within 1 LSB; known-value anchors (white, black, mid-grays, primary hues).

`browser/tests/ColorRampTest.cpp` — monotonic tone progression; chroma curve behavior at peak; dark-mode asymmetry; gamut clipping.
