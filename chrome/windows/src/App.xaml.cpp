#include "pch.h"
#include "App.xaml.h"
#include "MainWindow.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;

namespace winrt::webkitium::implementation {

App::App() {
    InitializeComponent();

    // Surface exceptions from the XAML framework during development.
    // Stripped in release builds by the default UnhandledException noop.
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
    m_window = make<MainWindow>();
    m_window.Activate();
}

}  // namespace winrt::webkitium::implementation
