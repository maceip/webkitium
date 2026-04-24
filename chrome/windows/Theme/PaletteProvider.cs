// Runtime palette applier -- C# edition.
//
// Replaces chrome/windows/src/PaletteProvider.{h,cpp} from the old
// C++/WinRT shell, keeping the same contract: find every semantic
// SolidColorBrush in the merged resource tree and mutate its Color in
// place when a new brand seed is applied. WinUI's ThemeResource
// references pick up the change automatically via the DP notifier.

using System;
using System.Collections.Generic;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using Webkitium.Platform;

namespace Webkitium.Theme;

internal sealed class PaletteProvider
{
    // Dev rotation -- same four seeds as the macOS and Android shells so
    // side-by-side comparisons are meaningful. Removed when the real
    // theme editor ships.
    private static readonly uint[] DevSeeds =
    {
        WebkitiumColorNative.DefaultBrandSeedArgb,  // webkitium blue
        0xFFD21F6B,                                 // deep magenta
        0xFF2D7A3E,                                 // forest green
        0xFF454B55,                                 // near-monochrome
    };

    private readonly Dictionary<string, SolidColorBrush> _lightBrushes = new();
    private readonly Dictionary<string, SolidColorBrush> _darkBrushes = new();
    private int _devIndex;

    public uint CurrentSeedArgb { get; private set; } = WebkitiumColorNative.DefaultBrandSeedArgb;

    public event EventHandler<uint>? SeedChanged;

    /// <summary>
    /// Locate the Light and Dark ThemeDictionaries inside the merged
    /// Tokens.xaml dictionary and cache a SolidColorBrush reference for
    /// each known semantic token name. Call once after Application
    /// resources are loaded, before the first ApplySeed.
    /// </summary>
    public void Initialize(ResourceDictionary applicationResources)
    {
        foreach (var merged in applicationResources.MergedDictionaries)
        {
            if (!merged.ThemeDictionaries.TryGetValue("Light", out var lightObj)) continue;
            if (!merged.ThemeDictionaries.TryGetValue("Dark", out var darkObj)) continue;
            if (lightObj is ResourceDictionary light && darkObj is ResourceDictionary dark)
            {
                CacheBrushes(_lightBrushes, light);
                CacheBrushes(_darkBrushes, dark);
                break;  // first merged dictionary wins -- it's Tokens.xaml
            }
        }
    }

    public void ApplySeed(uint argb)
    {
        var light = WebkitiumColorNative.Resolve(argb, dark: false);
        var dark = WebkitiumColorNative.Resolve(argb, dark: true);
        if (light is null || dark is null) return;

        ApplyToBrushes(_lightBrushes, light);
        ApplyToBrushes(_darkBrushes, dark);

        CurrentSeedArgb = argb;
        SeedChanged?.Invoke(this, argb);
    }

    public void CycleDevSeed()
    {
        _devIndex = (_devIndex + 1) % DevSeeds.Length;
        ApplySeed(DevSeeds[_devIndex]);
    }

    private static void CacheBrushes(Dictionary<string, SolidColorBrush> cache, ResourceDictionary dict)
    {
        foreach (var entry in dict)
        {
            if (entry.Key is string key && entry.Value is SolidColorBrush brush)
            {
                cache[key] = brush;
            }
        }
    }

    private static void ApplyToBrushes(Dictionary<string, SolidColorBrush> cache, Windows.UI.Color[] resolved)
    {
        for (var i = 0; i < resolved.Length; i++)
        {
            var name = WebkitiumColorNative.SemanticName(i);
            if (name is null) continue;
            if (cache.TryGetValue(name, out var brush))
            {
                brush.Color = resolved[i];
            }
        }
    }
}
