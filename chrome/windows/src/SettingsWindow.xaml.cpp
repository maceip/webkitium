#include "pch.h"
#include "SettingsWindow.xaml.h"
#if __has_include("SettingsWindow.g.cpp")
#include "SettingsWindow.g.cpp"
#endif

#include <winrt/Microsoft.UI.Windowing.h>
// xaml_typename<>() and TypeName live in Windows::UI::Xaml::Interop --
// WinUI 3's Frame::Navigate accepts that Windows-namespace TypeName
// directly; there is no Microsoft::UI::Xaml::Interop::TypeName.
#include <winrt/Windows.UI.Xaml.Interop.h>

#include "SettingsPairedDevicesPage.xaml.h"
#include "SettingsThemePage.xaml.h"
#include "SettingsPasswordsPage.xaml.h"

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Controls;
using namespace Windows::UI::Xaml::Interop;

namespace winrt::webkitium::implementation {

SettingsWindow::SettingsWindow() {
    InitializeComponent();
    InitializeTitleBar();

    if (auto appWindow = this->AppWindow()) {
        appWindow.Resize({ 900, 640 });
    }
    this->Title(L"Webkitium Settings");

    // Start on Paired devices.
    NavigateTo(L"paired-devices");
}

void SettingsWindow::InitializeTitleBar() {
    this->ExtendsContentIntoTitleBar(true);
    this->SetTitleBar(this->TitleBarStrip());
}

void SettingsWindow::AttachPaletteProvider(std::shared_ptr<PaletteProvider> palette) {
    m_palette = std::move(palette);
}

void SettingsWindow::OnNavigationSelectionChanged(
    NavigationView const&,
    NavigationViewSelectionChangedEventArgs const& args) {
    if (auto item = args.SelectedItem().try_as<NavigationViewItem>()) {
        auto tag = winrt::unbox_value_or<hstring>(item.Tag(), L"");
        NavigateTo(tag);
    }
}

void SettingsWindow::NavigateTo(std::wstring_view page_tag) {
    auto frame = this->ContentFrame();

    TypeName page_type{};
    if (page_tag == L"paired-devices") {
        page_type = xaml_typename<winrt::webkitium::SettingsPairedDevicesPage>();
    } else if (page_tag == L"theme") {
        page_type = xaml_typename<winrt::webkitium::SettingsThemePage>();
    } else if (page_tag == L"passwords") {
        page_type = xaml_typename<winrt::webkitium::SettingsPasswordsPage>();
    } else {
        return;
    }

    frame.Navigate(page_type);

    // After navigation, hand the PaletteProvider to the Theme page so
    // it can call ApplySeed on user input.  Other pages ignore this
    // handle.
    if (page_tag == L"theme") {
        if (auto page = frame.Content().try_as<webkitium::SettingsThemePage>()) {
            if (auto impl = winrt::get_self<SettingsThemePage>(page)) {
                impl->AttachPaletteProvider(m_palette);
            }
        }
    }
}

}  // namespace winrt::webkitium::implementation
