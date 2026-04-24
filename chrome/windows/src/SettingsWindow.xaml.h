// Webkitium Windows shell -- Settings window.
//
// MicaAlt backdrop + NavigationView sidebar with three stub pages:
//   - Paired devices (read-only list, mock data shaped like
//     LoopbackSyncServer output)
//   - Theme (ColorPicker wired to PaletteProvider::ApplySeed -- the
//     only page that touches live app state right now)
//   - Passwords (read-only log, mock data shaped like WebAuthnController
//     event records)
//
// Opens from MainWindow via Ctrl+, and from the Omnibar overflow button.

#pragma once

#include "SettingsWindow.g.h"
#include "PaletteProvider.h"

#include <memory>

namespace winrt::webkitium::implementation {

struct SettingsWindow : SettingsWindowT<SettingsWindow> {
    SettingsWindow();

    // Called by App::OpenSettings before the window is activated.  The
    // Theme page reaches through here to call ApplySeed when the user
    // picks a color.
    void AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette);

private:
    void InitializeTitleBar();
    void NavigateTo(std::wstring_view page_tag);
    void OnNavigationSelectionChanged(
        Microsoft::UI::Xaml::Controls::NavigationView const& sender,
        Microsoft::UI::Xaml::Controls::NavigationViewSelectionChangedEventArgs const& args);

    std::shared_ptr<PaletteProvider> m_palette;
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct SettingsWindow : SettingsWindowT<SettingsWindow, implementation::SettingsWindow> {};
}
