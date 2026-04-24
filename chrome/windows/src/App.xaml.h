// Webkitium Windows shell -- Application bootstrap.
//
// Owns the process-global PaletteProvider + references to the two long-
// lived windows (MainWindow and SettingsWindow).  MainWindow calls
// OpenSettings() when the user hits Ctrl+, -- App constructs the
// SettingsWindow lazily the first time and keeps it for reuse.

#pragma once

#include "App.xaml.g.h"
#include "PaletteProvider.h"

#include <memory>

namespace winrt::webkitium::implementation {

struct App : AppT<App> {
    App();

    void OnLaunched(
        Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);

    // Lazily construct and activate the Settings window.  Safe to call
    // repeatedly -- second call just re-activates the existing window.
    void OpenSettings();

    // Convenience for call sites that only have an Application handle.
    static App* Current();

private:
    Microsoft::UI::Xaml::Window      m_window{ nullptr };
    Microsoft::UI::Xaml::Window      m_settings_window{ nullptr };
    std::shared_ptr<PaletteProvider> m_palette;
};

}  // namespace winrt::webkitium::implementation
