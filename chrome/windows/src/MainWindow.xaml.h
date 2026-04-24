// Webkitium Windows shell -- top-level window.
//
// Owns:
//  - Custom title bar wiring (ExtendsContentIntoTitleBar + SetTitleBar)
//  - Layout: [omnibar band] / [content surface]
//  - Dev-only palette cycling shortcut (Ctrl+Shift+T)
//
// Does NOT own:
//  - Mica backdrop (declared in MainWindow.xaml)
//  - Palette values (live in Tokens.xaml, resolved via {ThemeResource ...},
//    mutated at runtime by PaletteProvider)

#pragma once

#include "MainWindow.g.h"
#include "PaletteProvider.h"

#include <memory>

namespace winrt::webkitium::implementation {

struct MainWindow : MainWindowT<MainWindow> {
    MainWindow();

    // Called by App::OnLaunched after it has constructed and initialized
    // the process-global PaletteProvider. The window uses it only for the
    // dev-only theme-cycling accelerator; production palette updates flow
    // through the extension API host, not this path.
    void AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette);

private:
    void InitializeTitleBar();
    void InstallThemeCyclingShortcut();
    void OnThemeCycleInvoked(
        Microsoft::UI::Xaml::Input::KeyboardAccelerator const& sender,
        Microsoft::UI::Xaml::Input::KeyboardAcceleratorInvokedEventArgs const& args);

    std::shared_ptr<PaletteProvider> m_palette;
    int m_test_seed_index = 0;
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow> {};
}
