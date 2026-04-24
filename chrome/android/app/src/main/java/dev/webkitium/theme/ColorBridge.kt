package dev.webkitium.theme

import androidx.compose.ui.graphics.Color

/**
 * JNI bridge into [browser/color/ColorBridgeC.h].
 *
 * The companion object declares the native methods; the shared
 * library is loaded once on class initialization.  Keep this file
 * thin -- any derived logic (semantic token enum, Material mapping)
 * belongs in [WebkitiumTheme].
 */
object ColorBridge {

    init {
        System.loadLibrary("webkitium_color_jni")
    }

    // Matches WK_SEMANTIC_TOKEN_COUNT from ColorBridgeC.h.
    const val SEMANTIC_TOKEN_COUNT: Int = 22

    // #FF1F5AE0 as a signed int (Kotlin Int is 32-bit signed, so the
    // high bit flips to make this negative; JNI still ships the raw
    // bits unchanged).
    const val DEFAULT_BRAND_SEED_ARGB: Int = 0xFF1F5AE0.toInt()

    /**
     * Resolve the 22 semantic tokens for [seedArgb] under the given
     * appearance.  Returns null if the native call failed.
     */
    fun resolveSemantic(seedArgb: Int, dark: Boolean): IntArray? =
        nativeResolveSemantic(seedArgb, dark)

    /**
     * Human-readable name for the semantic token at [index] -- matches
     * the names used by Windows/macOS shells (e.g. "SurfaceChrome").
     */
    fun semanticName(index: Int): String? = nativeSemanticName(index)

    @JvmStatic
    private external fun nativeResolveSemantic(
        seedArgb: Int,
        dark: Boolean,
    ): IntArray?

    @JvmStatic
    private external fun nativeSemanticName(index: Int): String?
}

/**
 * Stable ordering -- mirrors browser/color/SemanticPalette.h's
 * SemanticToken enum and chrome/macos's Swift enum.  Index equals the
 * slot in [IntArray] returned by [ColorBridge.resolveSemantic].
 */
enum class SemanticToken(val index: Int) {
    SurfaceCanvas(0),
    SurfaceChrome(1),
    SurfaceChromeRaised(2),
    SurfaceSunken(3),
    SurfaceHover(4),
    SurfacePressed(5),
    SurfaceOverlay(6),
    SurfaceSelected(7),
    TextPrimary(8),
    TextSecondary(9),
    TextTertiary(10),
    TextOnBrand(11),
    TextLink(12),
    BorderSubtle(13),
    BorderDefault(14),
    BorderStrong(15),
    BorderFocus(16),
    AccentFill(17),
    AccentFillHover(18),
    AccentFillPressed(19),
    AccentFillSubtle(20),
    TextDanger(21),
}

/**
 * Compose-side palette: indexed by [SemanticToken].  Produced once per
 * seed change per appearance by [PaletteProvider].
 */
class SemanticPalette(private val colors: IntArray) {
    operator fun get(token: SemanticToken): Color = Color(colors[token.index])

    companion object {
        val EMPTY = SemanticPalette(IntArray(ColorBridge.SEMANTIC_TOKEN_COUNT))

        fun resolve(seedArgb: Int, dark: Boolean): SemanticPalette {
            val raw = ColorBridge.resolveSemantic(seedArgb, dark)
                ?: return EMPTY
            return SemanticPalette(raw)
        }
    }
}
