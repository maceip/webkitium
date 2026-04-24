// Windows DLL export stamp for browser/color/ColorBridgeC.h.
//
// ColorBridgeC.h declares the C ABI; ColorBridgeC.cc defines the
// implementation. On Windows we need the symbols exported from the DLL
// so C# can find them via DllImport. The cleanest way to do that
// without touching the portable header is to re-declare the two
// functions here with __declspec(dllexport) and forward them.

#include <cstdint>

extern "C" {
    // Pulled directly from browser/color/ColorBridgeC.h. Repeated here
    // so the DLL-export decoration doesn't leak back into the portable
    // header (which is also consumed by Swift, Kotlin/JNI, and the
    // non-Windows CMake builds where dllexport is meaningless).
    int  wk_palette_resolve_semantic(uint32_t seed_argb,
                                     int dark,
                                     uint32_t* out_argb);
    const char* wk_palette_semantic_name(int index);

    __declspec(dllexport)
    int wk_palette_resolve_semantic_export(uint32_t seed_argb,
                                           int dark,
                                           uint32_t* out_argb) {
        return wk_palette_resolve_semantic(seed_argb, dark, out_argb);
    }

    __declspec(dllexport)
    const char* wk_palette_semantic_name_export(int index) {
        return wk_palette_semantic_name(index);
    }
}
