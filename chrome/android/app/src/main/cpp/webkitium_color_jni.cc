// JNI wrapper around browser/color/ColorBridgeC.h.
//
// Kotlin side declares these as `external fun` in ColorBridge.kt. The
// signatures below match Kotlin's JNI name-mangling for
// `package dev.webkitium.theme; class ColorBridge`.
//
// No C++ logic here -- just a thin marshal that wraps
// wk_palette_resolve_semantic() into a jintArray return. All math lives
// in the portable C++ library.

#include <jni.h>

#include "color/ColorBridgeC.h"

extern "C"
JNIEXPORT jintArray JNICALL
Java_dev_webkitium_theme_ColorBridge_nativeResolveSemantic(
    JNIEnv* env,
    jclass /*clazz*/,
    jint seed_argb,
    jboolean dark) {

    uint32_t out[WK_SEMANTIC_TOKEN_COUNT] = { 0 };
    if (!wk_palette_resolve_semantic(static_cast<uint32_t>(seed_argb),
                                     dark ? 1 : 0,
                                     out)) {
        return nullptr;
    }

    jintArray result = env->NewIntArray(WK_SEMANTIC_TOKEN_COUNT);
    if (result == nullptr) return nullptr;

    // Safe cast: same bit width, and SemanticPalette returns ARGB values
    // with alpha=0xFF so the sign bit is set. Kotlin reads them back via
    // `Color(toArgb = argb)` which takes an Int and interprets the sign
    // bit as the alpha channel's high bit.
    env->SetIntArrayRegion(
        result, 0, WK_SEMANTIC_TOKEN_COUNT,
        reinterpret_cast<const jint*>(out));

    return result;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_dev_webkitium_theme_ColorBridge_nativeSemanticName(
    JNIEnv* env,
    jclass /*clazz*/,
    jint index) {

    const char* name = wk_palette_semantic_name(index);
    return name ? env->NewStringUTF(name) : nullptr;
}
