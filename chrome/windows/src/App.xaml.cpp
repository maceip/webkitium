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
    // Bring up the runtime palette system. At this point App.xaml has
    // already merged Tokens.xaml, so the SolidColorBrush instances in the
    // Light/Dark ThemeDictionaries exist and can be cached. We then apply
    // the shipped default seed -- this is a no-op visually (values were
    // already the algorithm's output for the same seed) but it locks in
    // the invariant that every visible color flowed through
    // browser/color/ColorRamp.cpp.
    m_palette = std::make_shared<PaletteProvider>();
    m_palette->Initialize();
    m_palette->ApplySeed(PaletteProvider::kShippedDefaultSeedArgb);

    m_window = make<MainWindow>();

    // MainWindow needs a handle to the palette for the dev-only cycling
    // shortcut. When the browser.theme extension API lands, the window
    // no longer carries this reference -- the extension host owns it and
    // the window observes changes through brush bindings only.
    if (auto impl = winrt::get_self<MainWindow>(m_window)) {
        impl->AttachPaletteProvider(m_palette);
    }

    m_window.Activate();
}

}  // namespace winrt::webkitium::implementation
