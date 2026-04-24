// Runtime palette applier for the Windows shell.
//
// At app launch, Initialize() finds every semantic SolidColorBrush in
// Tokens.xaml's Light and Dark ThemeDictionaries and caches a handle to
// it. ApplySeed(argb) calls browser/color/GeneratePalette(),
// ResolveSemanticPalette() twice (once per appearance), and mutates the
// cached brushes' Color DependencyProperties in place. WinUI's render
// pipeline re-paints all bound controls automatically because brush.Color
// is a DP.
//
// Thread rule: call only from the UI thread that owns Application.Current.
// The browser.theme extension API will marshal onto the UI DispatcherQueue
// before invoking.

#pragma once

#include "pch.h"

#include <array>
#include <cstdint>
#include <string_view>

#include "color/SemanticPalette.h"

namespace winrt::webkitium::implementation {

class PaletteProvider {
public:
    // Locate the Light and Dark ThemeDictionaries inside Tokens.xaml and
    // cache a SolidColorBrush reference for each semantic token name.
    // Does not apply any seed -- call ApplySeed() next.
    void Initialize();

    // Regenerate palettes from the seed and push into every cached
    // brush. Returns false if Initialize() has not run yet.
    bool ApplySeed(uint32_t argb);

    // Last applied seed (for persistence / diagnostics).
    uint32_t CurrentSeed() const { return m_seed; }

    // Expose the default shipped seed so MainWindow's dev-only cycling
    // shortcut can include it in its rotation.
    static constexpr uint32_t kShippedDefaultSeedArgb = 0xFF1F5AE0;

private:
    using BrushArray = std::array<
        Microsoft::UI::Xaml::Media::SolidColorBrush,
        ::webkitium::color::kSemanticTokenCount>;

    void CacheBrushes(BrushArray& out,
                      Microsoft::UI::Xaml::ResourceDictionary const& dict);

    void ApplyToBrushes(BrushArray const& brushes,
                        ::webkitium::color::SemanticPalette const& palette);

    BrushArray m_light_brushes{};
    BrushArray m_dark_brushes{};
    bool       m_initialized = false;
    uint32_t   m_seed = 0;
};

}  // namespace winrt::webkitium::implementation
