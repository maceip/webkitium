// P/Invoke wrapper around browser/color/ColorBridgeC.h (Windows side).
//
// The native DLL is built by native/webkitium_color.vcxproj and copied
// next to the managed EXE. DllImport("webkitium_color") resolves against
// that sidecar.
//
// Export names are the *_export suffixed variants declared in
// native/webkitium_color_exports.cc so the portable C header
// (ColorBridgeC.h) can stay free of Windows-specific __declspec markers.

using System;
using System.Runtime.InteropServices;
using Windows.UI;

namespace Webkitium.Platform;

internal static class WebkitiumColorNative
{
    // Mirrors WK_SEMANTIC_TOKEN_COUNT. Callers using this constant
    // instead of the hard-coded number get single-point-of-truth
    // if the enum ever grows.
    public const int SemanticTokenCount = 22;

    // Mirrors WK_DEFAULT_BRAND_SEED_ARGB.
    public const uint DefaultBrandSeedArgb = 0xFF1F5AE0;

    [DllImport("webkitium_color", EntryPoint = "wk_palette_resolve_semantic_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkPaletteResolveSemantic(
        uint seedArgb,
        int dark,
        [Out] uint[] outArgb);

    [DllImport("webkitium_color", EntryPoint = "wk_palette_semantic_name_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkPaletteSemanticName(int index);

    /// <summary>
    /// Resolve the 22 semantic tokens for a given brand seed and
    /// appearance. Returns null on native failure.
    /// </summary>
    public static Color[]? Resolve(uint seedArgb, bool dark)
    {
        var raw = new uint[SemanticTokenCount];
        var ok = WkPaletteResolveSemantic(seedArgb, dark ? 1 : 0, raw);
        if (ok == 0) return null;

        var colors = new Color[SemanticTokenCount];
        for (var i = 0; i < SemanticTokenCount; i++)
        {
            colors[i] = Color.FromArgb(
                (byte)((raw[i] >> 24) & 0xFF),
                (byte)((raw[i] >> 16) & 0xFF),
                (byte)((raw[i] >> 8) & 0xFF),
                (byte)(raw[i] & 0xFF));
        }
        return colors;
    }

    /// <summary>
    /// Human-readable name of the semantic token at <paramref name="index"/>
    /// -- e.g. "SurfaceChrome", "AccentFill". Matches the names used by
    /// the macOS Swift shell and Android Kotlin shell.
    /// </summary>
    public static string? SemanticName(int index)
    {
        var ptr = WkPaletteSemanticName(index);
        return ptr == IntPtr.Zero ? null : Marshal.PtrToStringAnsi(ptr);
    }
}

/// <summary>
/// Index into the semantic palette array. Ordering is stable and mirrors
/// browser/color/SemanticPalette.h's SemanticToken enum exactly.
/// </summary>
internal enum SemanticToken
{
    SurfaceCanvas = 0,
    SurfaceChrome,
    SurfaceChromeRaised,
    SurfaceSunken,
    SurfaceHover,
    SurfacePressed,
    SurfaceOverlay,
    SurfaceSelected,
    TextPrimary,
    TextSecondary,
    TextTertiary,
    TextOnBrand,
    TextLink,
    BorderSubtle,
    BorderDefault,
    BorderStrong,
    BorderFocus,
    AccentFill,
    AccentFillHover,
    AccentFillPressed,
    AccentFillSubtle,
    TextDanger,
}
