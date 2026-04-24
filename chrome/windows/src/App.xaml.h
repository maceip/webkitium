// Webkitium Windows shell -- Application bootstrap.
//
// Owns the process-global PaletteProvider and routes it to MainWindow so
// the dev-only theme-cycling shortcut has a handle to mutate live
// brushes. In production this same PaletteProvider is driven by the
// browser.theme extension API host rather than the window.

#pragma once

#include "App.xaml.g.h"
#include "PaletteProvider.h"

#include <memory>

namespace winrt::webkitium::implementation {

struct App : AppT<App> {
    App();

    void OnLaunched(
        Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);

private:
    Microsoft::UI::Xaml::Window      m_window{ nullptr };
    std::shared_ptr<PaletteProvider> m_palette;
};

}  // namespace winrt::webkitium::implementation
