// Webkitium Windows shell — Application bootstrap.

#pragma once

#include "App.xaml.g.h"

namespace winrt::webkitium::implementation {

struct App : AppT<App> {
    App();

    void OnLaunched(
        Microsoft::UI::Xaml::LaunchActivatedEventArgs const& args);

private:
    Microsoft::UI::Xaml::Window m_window{ nullptr };
};

}  // namespace winrt::webkitium::implementation
