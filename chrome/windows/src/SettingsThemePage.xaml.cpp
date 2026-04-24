#include "pch.h"
#include "SettingsThemePage.xaml.h"
#if __has_include("SettingsThemePage.g.cpp")
#include "SettingsThemePage.g.cpp"
#endif

#include <winrt/Microsoft.UI.h>
#include <winrt/Windows.UI.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>

#include <cwchar>
#include <string>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Microsoft::UI::Xaml::Media;
using namespace Windows::UI;

namespace winrt::webkitium::implementation {

SettingsThemePage::SettingsThemePage() {
    InitializeComponent();
}

void SettingsThemePage::AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette) {
    m_palette = std::move(palette);
    if (!m_palette) return;

    // Seed the picker + swatch + hex readout from the live provider so
    // the page opens showing the currently-applied color rather than the
    // XAML default.
    const uint32_t current = m_palette->CurrentSeed();

    m_suppress_picker_event = true;
    Color picker_color{
        /*A=*/0xFF,
        /*R=*/static_cast<uint8_t>((current >> 16) & 0xFF),
        /*G=*/static_cast<uint8_t>((current >> 8)  & 0xFF),
        /*B=*/static_cast<uint8_t>((current >> 0)  & 0xFF),
    };
    this->SeedPicker().Color(picker_color);
    m_suppress_picker_event = false;

    ApplySeedAndRefreshUi(current);
}

void SettingsThemePage::OnSeedPickerColorChanged(
    ColorPicker const&,
    ColorChangedEventArgs const& args) {
    if (m_suppress_picker_event) return;

    const Color c = args.NewColor();
    const uint32_t argb =
        (0xFFu << 24) |
        (static_cast<uint32_t>(c.R) << 16) |
        (static_cast<uint32_t>(c.G) << 8)  |
        (static_cast<uint32_t>(c.B) << 0);

    ApplySeedAndRefreshUi(argb);
}

void SettingsThemePage::OnPresetClicked(
    IInspectable const& sender,
    RoutedEventArgs const&) {
    if (auto button = sender.try_as<Button>()) {
        auto tag = winrt::unbox_value_or<hstring>(button.Tag(), L"");
        if (tag.empty()) return;

        const uint32_t argb = ArgbFromHexString(std::wstring_view{ tag });

        // Echo the preset into the picker (without re-firing a palette
        // update -- we'll do it once via ApplySeedAndRefreshUi).
        m_suppress_picker_event = true;
        Color c{
            0xFF,
            static_cast<uint8_t>((argb >> 16) & 0xFF),
            static_cast<uint8_t>((argb >> 8)  & 0xFF),
            static_cast<uint8_t>((argb >> 0)  & 0xFF),
        };
        this->SeedPicker().Color(c);
        m_suppress_picker_event = false;

        ApplySeedAndRefreshUi(argb);
    }
}

void SettingsThemePage::ApplySeedAndRefreshUi(uint32_t argb) {
    if (m_palette) {
        m_palette->ApplySeed(argb);
    }

    // Update the readout text + swatch tile.
    wchar_t buf[16];
    std::swprintf(buf, sizeof(buf)/sizeof(wchar_t), L"#%02X%02X%02X",
                  (argb >> 16) & 0xFF,
                  (argb >> 8)  & 0xFF,
                  (argb >> 0)  & 0xFF);
    this->CurrentSeedHex().Text(hstring{ buf });

    auto swatch_brush = SolidColorBrush{ Color{
        0xFF,
        static_cast<uint8_t>((argb >> 16) & 0xFF),
        static_cast<uint8_t>((argb >> 8)  & 0xFF),
        static_cast<uint8_t>((argb >> 0)  & 0xFF),
    } };
    this->CurrentSeedSwatch().Background(swatch_brush);
}

uint32_t SettingsThemePage::ArgbFromHexString(std::wstring_view hex) {
    // Expects "#FFRRGGBB".  Lax on length -- non-hex characters yield 0
    // which is benign (falls back to transparent black).
    if (hex.size() < 9 || hex[0] != L'#') return 0;

    auto nibble = [](wchar_t c) -> uint32_t {
        if (c >= L'0' && c <= L'9') return c - L'0';
        if (c >= L'a' && c <= L'f') return 10 + (c - L'a');
        if (c >= L'A' && c <= L'F') return 10 + (c - L'A');
        return 0;
    };

    uint32_t out = 0;
    for (size_t i = 1; i < 9; ++i) {
        out = (out << 4) | nibble(hex[i]);
    }
    return out;
}

}  // namespace winrt::webkitium::implementation
