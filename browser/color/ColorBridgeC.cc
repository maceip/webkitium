#include "color/ColorBridgeC.h"

#include <cstddef>
#include <cstdint>

#include "color/ColorRamp.h"
#include "color/SemanticPalette.h"

extern "C" {

int wk_palette_resolve_semantic(uint32_t seed_argb,
                                int dark,
                                uint32_t* out_argb) {
    if (!out_argb) return 0;

    const webkitium::color::Srgb seed{
        static_cast<uint8_t>((seed_argb >> 16) & 0xFF),
        static_cast<uint8_t>((seed_argb >> 8)  & 0xFF),
        static_cast<uint8_t>((seed_argb >> 0)  & 0xFF),
    };

    const auto palette  = webkitium::color::GeneratePalette(seed);
    const auto semantic =
        webkitium::color::ResolveSemanticPalette(palette, dark != 0);

    for (int i = 0; i < WK_SEMANTIC_TOKEN_COUNT; ++i) {
        out_argb[i] = semantic.colors[i].ToArgb();
    }
    return 1;
}

const char* wk_palette_semantic_name(int index) {
    if (index < 0 || index >= WK_SEMANTIC_TOKEN_COUNT) return nullptr;

    // kSemanticTokenNames is std::array<std::string_view, ...> backed by
    // static string literals, so the returned c_str() pointer is stable
    // for the lifetime of the process.
    return webkitium::color::kSemanticTokenNames[
        static_cast<size_t>(index)].data();
}

}  // extern "C"
