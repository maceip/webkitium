// Pure-C ABI wrapper around browser/color/.
//
// Exists so Swift (macOS / iOS) and Kotlin (Android, via JNI) can call the
// same palette generator as the C++ Windows shell. No C++ symbols crossing
// the boundary, no exception propagation, no STL in the header -- just
// flat arrays of uint32_t ARGB values.
//
// The semantic token order matches browser/color/SemanticPalette.h's
// SemanticToken enum and kSemanticTokenNames array. Callers should treat
// the output index as a stable contract.

#ifndef WEBKITIUM_COLOR_BRIDGE_C_H_
#define WEBKITIUM_COLOR_BRIDGE_C_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Number of semantic tokens returned by wk_palette_resolve_semantic.
// Callers must pre-allocate this many uint32_t slots.
#define WK_SEMANTIC_TOKEN_COUNT 22

// Default shipped brand seed as an opaque ARGB. #FF1F5AE0 (webkitium blue).
// Callers typically use this at first run before user sync settles.
#define WK_DEFAULT_BRAND_SEED_ARGB 0xFF1F5AE0u

// Fill the `out_argb` array with the 22 semantic token values derived from
// `seed_argb`. The `dark` flag picks the dark-appearance resolver.
//
// out_argb must point to at least WK_SEMANTIC_TOKEN_COUNT uint32_t slots.
// Values are ARGB (0xAARRGGBB), alpha always 0xFF.
//
// Returns 1 on success, 0 if out_argb is null.
//
// Thread-safe. No global state; safe to call concurrently.
int wk_palette_resolve_semantic(uint32_t seed_argb,
                                int dark,
                                uint32_t* out_argb);

// Lookup helper: name of the semantic token at `index` in [0,
// WK_SEMANTIC_TOKEN_COUNT). Returns a pointer to a static, null-terminated
// ASCII string -- e.g. "SurfaceChrome", "AccentFill". Returns nullptr if
// the index is out of range.
const char* wk_palette_semantic_name(int index);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_COLOR_BRIDGE_C_H_
