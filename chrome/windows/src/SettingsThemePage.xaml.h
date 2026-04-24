// Settings -> Theme page.  The only stub page that touches live state:
// the ColorPicker and preset swatches both call into
// PaletteProvider::ApplySeed, which regenerates the 24-color palette
// via browser/color/ColorRamp.cpp and mutates every brush in place.

#pragma once

#include "SettingsThemePage.g.h"
#include "PaletteProvider.h"

#include <memory>

namespace winrt::webkitium::implementation {

struct SettingsThemePage : SettingsThemePageT<SettingsThemePage> {
    SettingsThemePage();

    void AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette);

    void OnSeedPickerColorChanged(
        Microsoft::UI::Xaml::Controls::ColorPicker const& sender,
        Microsoft::UI::Xaml::Controls::ColorChangedEventArgs const& args);

    void OnPresetClicked(
        Windows::Foundation::IInspectable const& sender,
        Microsoft::UI::Xaml::RoutedEventArgs const& args);

private:
    void ApplySeedAndRefreshUi(uint32_t argb);
    static uint32_t ArgbFromHexString(std::wstring_view hex);

    std::shared_ptr<PaletteProvider> m_palette;
    bool m_suppress_picker_event = false;
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct SettingsThemePage : SettingsThemePageT<SettingsThemePage, implementation::SettingsThemePage> {};
}
