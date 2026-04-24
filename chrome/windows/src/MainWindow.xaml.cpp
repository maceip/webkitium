#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
#endif

#include <winrt/Microsoft.UI.Windowing.h>
#include <winrt/Windows.Graphics.h>
#include <winrt/Windows.System.h>

#include <array>

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Input;
using namespace Windows::System;

namespace winrt::webkitium::implementation {
namespace {

// Dev-only cycle. Ctrl+Shift+T advances through these seeds to visually
// confirm the end-to-end runtime theme update path:
//   0: webkitium blue   (shipped default)
//   1: deep magenta     (saturated)
//   2: forest green     (warm mid-chroma)
//   3: near-monochrome  (validates the near-gray seed path)
constexpr std::array<uint32_t, 4> kTestSeeds = {
    0xFF1F5AE0,  // PaletteProvider::kShippedDefaultSeedArgb
    0xFFD21F6B,
    0xFF2D7A3E,
    0xFF454B55,
};

}  // namespace

MainWindow::MainWindow() {
    InitializeComponent();
    InitializeTitleBar();
    InstallThemeCyclingShortcut();

    auto appWindow = this->AppWindow();
    if (appWindow) {
        appWindow.Resize({ 1280, 800 });
    }
    this->Title(L"Webkitium");
}

void MainWindow::InitializeTitleBar() {
    this->ExtendsContentIntoTitleBar(true);
    this->SetTitleBar(this->OmnibarHost());
}

void MainWindow::AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette) {
    m_palette = std::move(palette);
}

void MainWindow::InstallThemeCyclingShortcut() {
    // KeyboardAccelerator attached to the root grid so it fires anywhere
    // in the window. TODO(webkitium#dev-shortcuts): remove once the
    // Settings -> Appearance -> Theme UI lands.
    KeyboardAccelerator accel;
    accel.Modifiers(VirtualKeyModifiers::Control | VirtualKeyModifiers::Shift);
    accel.Key(VirtualKey::T);
    accel.Invoked({ this, &MainWindow::OnThemeCycleInvoked });

    if (auto root = this->Content().try_as<FrameworkElement>()) {
        root.KeyboardAccelerators().Append(accel);
    }
}

void MainWindow::OnThemeCycleInvoked(
    KeyboardAccelerator const&,
    KeyboardAcceleratorInvokedEventArgs const& args) {
    args.Handled(true);
    if (!m_palette) return;

    m_test_seed_index = (m_test_seed_index + 1) % static_cast<int>(kTestSeeds.size());
    m_palette->ApplySeed(kTestSeeds[m_test_seed_index]);
}

}  // namespace winrt::webkitium::implementation
