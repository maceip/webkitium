#include "pch.h"
#include "MainWindow.xaml.h"
#if __has_include("MainWindow.g.cpp")
#include "MainWindow.g.cpp"
#endif

#include "App.xaml.h"
#include "Log.h"

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
    LOG_INFO("MainWindow::ctor entered");
    InitializeComponent();
    LOG_INFO("MainWindow::InitializeComponent returned");
    InitializeTitleBar();
    InstallThemeCyclingShortcut();
    InstallOpenSettingsShortcut();
    LOG_INFO("MainWindow shortcuts installed");

    auto appWindow = this->AppWindow();
    if (appWindow) {
        appWindow.Resize({ 1280, 800 });
        LOG_INFO("MainWindow AppWindow resized to 1280x800");
    } else {
        LOG_WARN("MainWindow::AppWindow() returned null");
    }
    this->Title(L"Webkitium");
    LOG_INFO("MainWindow::ctor exiting");
}

void MainWindow::InitializeTitleBar() {
    this->ExtendsContentIntoTitleBar(true);
    this->SetTitleBar(this->OmnibarHost());
}

void MainWindow::AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette) {
    m_palette = std::move(palette);
}

void MainWindow::InstallThemeCyclingShortcut() {
    // KeyboardAccelerator on the root grid.  IsEnabled and ScopeOwner
    // are both set explicitly -- without a scope owner the accelerator
    // only fires when the specific element has focus, which never
    // happens for the root Grid.  Logging on Invoked lets us confirm
    // the event actually fires.
    auto root = this->Content().try_as<FrameworkElement>();
    if (!root) {
        LOG_ERROR("InstallThemeCyclingShortcut: Content() is not FrameworkElement");
        return;
    }

    KeyboardAccelerator accel;
    accel.Modifiers(VirtualKeyModifiers::Control | VirtualKeyModifiers::Shift);
    accel.Key(VirtualKey::T);
    accel.ScopeOwner(root);
    accel.Invoked({ this, &MainWindow::OnThemeCycleInvoked });
    root.KeyboardAccelerators().Append(accel);

    LOG_INFO("Ctrl+Shift+T accelerator attached to root");
}

void MainWindow::OnThemeCycleInvoked(
    KeyboardAccelerator const&,
    KeyboardAcceleratorInvokedEventArgs const& args) {
    LOG_INFO("OnThemeCycleInvoked fired");
    args.Handled(true);
    if (!m_palette) {
        LOG_WARN("OnThemeCycleInvoked: m_palette is null");
        return;
    }

    m_test_seed_index = (m_test_seed_index + 1) % static_cast<int>(kTestSeeds.size());
    const uint32_t seed = kTestSeeds[m_test_seed_index];
    wchar_t buf[64];
    std::swprintf(buf, 64, L"cycling to seed #%d = 0x%08X",
                  m_test_seed_index, seed);
    LOG_INFO(std::wstring_view{ buf });
    m_palette->ApplySeed(seed);
}

void MainWindow::InstallOpenSettingsShortcut() {
    auto root = this->Content().try_as<FrameworkElement>();
    if (!root) {
        LOG_ERROR("InstallOpenSettingsShortcut: Content() is not FrameworkElement");
        return;
    }
    // Ctrl+, is the Windows convention for "open settings".  VK_OEM_COMMA
    // is 0xBC, not in the Windows.System.VirtualKey enum, so cast through.
    KeyboardAccelerator accel;
    accel.Modifiers(VirtualKeyModifiers::Control);
    accel.Key(static_cast<VirtualKey>(0xBC));
    accel.ScopeOwner(root);
    accel.Invoked({ this, &MainWindow::OnOpenSettingsInvoked });
    root.KeyboardAccelerators().Append(accel);

    LOG_INFO("Ctrl+, accelerator attached to root");
}

void MainWindow::OnOpenSettingsInvoked(
    KeyboardAccelerator const&,
    KeyboardAcceleratorInvokedEventArgs const& args) {
    LOG_INFO("OnOpenSettingsInvoked fired");
    args.Handled(true);
    if (auto app = implementation::App::Instance()) {
        app->OpenSettings();
    } else {
        LOG_ERROR("OnOpenSettingsInvoked: App::Instance() returned null");
    }
}

}  // namespace winrt::webkitium::implementation
