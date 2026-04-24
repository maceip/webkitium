#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
#endif

#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.Graphics.h>

using namespace winrt;
using namespace Microsoft::UI::Xaml;

namespace winrt::webkitium::implementation {

MainWindow::MainWindow() {
    InitializeComponent();
    InitializeTitleBar();

    // Reasonable first-launch size. User's last-used size takes over once
    // session persistence lands.
    auto appWindow = this->AppWindow();
    if (appWindow) {
        appWindow.Resize({ 1280, 800 });
    }

    // Window chrome title — used by taskbar + alt-tab until we render our
    // own presence indicator.
    this->Title(L"Webkitium");
}

void MainWindow::InitializeTitleBar() {
    // Opt into drawing into the title-bar region so the omnibar can sit in
    // it. Required for SetTitleBar(...) to take effect.
    this->ExtendsContentIntoTitleBar(true);

    // Mark the omnibar host as the draggable title-bar region. The pill
    // inside it is interactive; the padding around it stays draggable.
    this->SetTitleBar(this->OmnibarHost());
}

}  // namespace winrt::webkitium::implementation
