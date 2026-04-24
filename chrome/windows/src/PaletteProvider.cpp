#include "pch.h"
#include "PaletteProvider.h"
#include "Log.h"

#include <string>

#include "color/ColorRamp.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Media;
using namespace Windows::UI;

namespace winrt::webkitium::implementation {
namespace {

Color ToWinrtColor(::webkitium::color::Srgb c) {
    return Color{ /*A=*/0xFF, c.r, c.g, c.b };
}

std::wstring Widen(std::string_view s) {
    return std::wstring(s.begin(), s.end());
}

}  // namespace

void PaletteProvider::Initialize() {
    LOG_INFO("PaletteProvider::Initialize entered");
    // App.xaml merges Tokens.xaml as MergedDictionaries[0]. Walk down to
    // the ThemeDictionaries ("Light" / "Dark") and cache every brush we
    // recognize by name. Unknown or missing brushes are left as default-
    // constructed SolidColorBrush() handles; ApplySeed will no-op on them.
    auto appResources = Application::Current().Resources();
    auto merged       = appResources.MergedDictionaries();
    {
        wchar_t buf[128];
        std::swprintf(buf, 128, L"MergedDictionaries.Size() = %u",
                      static_cast<unsigned>(merged.Size()));
        LOG_INFO(std::wstring_view{ buf });
    }
    if (merged.Size() == 0) {
        LOG_WARN("No merged dictionaries -- Tokens.xaml missing?  Aborting Initialize.");
        return;
    }

    // The first merged dictionary must be Tokens.xaml.
    auto tokens = merged.GetAt(0);
    auto themes = tokens.ThemeDictionaries();

    auto light_ref = themes.Lookup(box_value(L"Light"));
    auto dark_ref  = themes.Lookup(box_value(L"Dark"));
    if (!light_ref || !dark_ref) {
        LOG_ERROR("ThemeDictionaries Light / Dark lookup failed");
        return;
    }

    auto light = light_ref.as<ResourceDictionary>();
    auto dark  = dark_ref.as<ResourceDictionary>();

    CacheBrushes(m_light_brushes, light);
    CacheBrushes(m_dark_brushes,  dark);
    m_initialized = true;

    int cached = 0;
    for (int i = 0; i < ::webkitium::color::kSemanticTokenCount; ++i) {
        if (m_light_brushes[i]) ++cached;
    }
    wchar_t buf[128];
    std::swprintf(buf, 128, L"Initialize ok -- cached %d of %d brushes (light)",
                  cached, ::webkitium::color::kSemanticTokenCount);
    LOG_INFO(std::wstring_view{ buf });
}

void PaletteProvider::CacheBrushes(
    BrushArray& out,
    ResourceDictionary const& dict) {
    for (int i = 0; i < ::webkitium::color::kSemanticTokenCount; ++i) {
        const auto key = Widen(::webkitium::color::kSemanticTokenNames[i]);
        auto box = dict.TryLookup(box_value(hstring(key)));
        if (!box) continue;
        if (auto brush = box.try_as<SolidColorBrush>()) {
            out[i] = brush;
        }
    }
}

bool PaletteProvider::ApplySeed(uint32_t argb) {
    if (!m_initialized) return false;

    ::webkitium::color::Srgb seed{
        static_cast<uint8_t>((argb >> 16) & 0xFF),
        static_cast<uint8_t>((argb >> 8)  & 0xFF),
        static_cast<uint8_t>((argb >> 0)  & 0xFF),
    };

    const auto palette = ::webkitium::color::GeneratePalette(seed);
    const auto light_semantic = ::webkitium::color::ResolveSemanticPalette(palette, /*dark=*/false);
    const auto dark_semantic  = ::webkitium::color::ResolveSemanticPalette(palette, /*dark=*/true);

    ApplyToBrushes(m_light_brushes, light_semantic);
    ApplyToBrushes(m_dark_brushes,  dark_semantic);

    m_seed = argb;
    return true;
}

void PaletteProvider::ApplyToBrushes(
    BrushArray const& brushes,
    ::webkitium::color::SemanticPalette const& palette) {
    for (int i = 0; i < ::webkitium::color::kSemanticTokenCount; ++i) {
        if (!brushes[i]) continue;  // brush not found in dictionary
        brushes[i].Color(ToWinrtColor(palette.colors[i]));
    }
}

}  // namespace winrt::webkitium::implementation
