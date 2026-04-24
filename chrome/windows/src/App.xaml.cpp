#include "pch.h"
#include "App.xaml.h"
#include "MainWindow.xaml.h"
#include "SettingsWindow.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;

namespace winrt::webkitium::implementation {

App::App() {
    InitializeComponent();

    s_instance = this;

    UnhandledException([](IInspectable const&,
                          UnhandledExceptionEventArgs const& e) {
        if (IsDebuggerPresent()) {
            auto const message = e.Message();
            __debugbreak();
            (void)message;
        }
    });
}

void App::OnLaunched(LaunchActivatedEventArgs const&) {
    m_palette = std::make_shared<PaletteProvider>();
    m_palette->Initialize();
    m_palette->ApplySeed(PaletteProvider::kShippedDefaultSeedArgb);

    m_window = make<implementation::MainWindow>();
    if (auto impl = winrt::get_self<implementation::MainWindow>(m_window)) {
        impl->AttachPaletteProvider(m_palette);
    }
    m_window.Activate();
}

void App::OpenSettings() {
    if (!m_settings_window) {
        m_settings_window = make<implementation::SettingsWindow>();
        if (auto impl =
                winrt::get_self<implementation::SettingsWindow>(m_settings_window)) {
            impl->AttachPaletteProvider(m_palette);
        }
    }
    m_settings_window.Activate();
}

}  // namespace winrt::webkitium::implementation
