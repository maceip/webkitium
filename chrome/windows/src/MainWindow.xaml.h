// Webkitium Windows shell — top-level window.
//
// Owns:
//  - Custom title bar wiring (ExtendsContentIntoTitleBar + SetTitleBar)
//  - Layout: [omnibar band] / [content surface]
//
// Does NOT own:
//  - Mica backdrop (declared in MainWindow.xaml)
//  - Palette values (live in Tokens.xaml, resolved via {ThemeResource ...})

#pragma once

#include "MainWindow.g.h"

namespace winrt::webkitium::implementation {

struct MainWindow : MainWindowT<MainWindow> {
    MainWindow();

private:
    void InitializeTitleBar();
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct MainWindow : MainWindowT<MainWindow, implementation::MainWindow> {};
}
