#include "pch.h"
#include "App.xaml.h"
#include "Log.h"
#include "MainWindow.xaml.h"
#include "SettingsWindow.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;

namespace winrt::webkitium::implementation {

App::App() {
    ::webkitium::log::Initialize();
    LOG_INFO("App::App ctor entered");
    InitializeComponent();
    LOG_INFO("App::InitializeComponent returned");

    s_instance = this;

    UnhandledException([](IInspectable const&,
                          UnhandledExceptionEventArgs const& e) {
        auto msg = e.Message();
        LOG_ERROR(std::wstring_view{ msg });
        if (IsDebuggerPresent()) {
            __debugbreak();
        }
    });
    LOG_INFO("App::App ctor exiting");
}

void App::OnLaunched(LaunchActivatedEventArgs const&) {
    LOG_INFO("App::OnLaunched entered");

    m_palette = std::make_shared<PaletteProvider>();
    LOG_INFO("PaletteProvider constructed");
    m_palette->Initialize();
    LOG_INFO("PaletteProvider::Initialize returned");
    const bool applied = m_palette->ApplySeed(PaletteProvider::kShippedDefaultSeedArgb);
    LOG_INFO(std::string_view{ applied ? "ApplySeed(default): ok" : "ApplySeed(default): failed" });

    LOG_INFO("make<MainWindow>() ...");
    m_window = make<implementation::MainWindow>();
    LOG_INFO("make<MainWindow>() returned");
    if (auto impl = winrt::get_self<implementation::MainWindow>(m_window)) {
        impl->AttachPaletteProvider(m_palette);
        LOG_INFO("MainWindow palette attached");
    }
    LOG_INFO("calling MainWindow.Activate()");
    m_window.Activate();
    LOG_INFO("App::OnLaunched returning (MainWindow activated)");
}

void App::OpenSettings() {
    LOG_INFO("App::OpenSettings invoked");
    if (!m_settings_window) {
        m_settings_window = make<implementation::SettingsWindow>();
        LOG_INFO("SettingsWindow created");
        if (auto impl =
                winrt::get_self<implementation::SettingsWindow>(m_settings_window)) {
            impl->AttachPaletteProvider(m_palette);
            LOG_INFO("SettingsWindow palette attached");
        }
    }
    m_settings_window.Activate();
    LOG_INFO("SettingsWindow activated");
}

}  // namespace winrt::webkitium::implementation
