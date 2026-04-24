// Webkitium Windows shell — Omnibar UserControl.
//
// Interaction contract: design/components/omnibar/SPEC.md.
// Visual tokens: Tokens.xaml (SurfaceSunken, BorderSubtle, AccentFill,
// TextPrimary, FontFamilyUI, RadiusOmnibar).

#pragma once

#include "Omnibar.g.h"

namespace winrt::webkitium::implementation {

struct Omnibar : OmnibarT<Omnibar> {
    Omnibar();

    // Event handlers wired from XAML.
    void OnInputGotFocus(Windows::Foundation::IInspectable const& sender,
                         Microsoft::UI::Xaml::RoutedEventArgs const& e);
    void OnInputLostFocus(Windows::Foundation::IInspectable const& sender,
                          Microsoft::UI::Xaml::RoutedEventArgs const& e);
    void OnInputKeyDown(Windows::Foundation::IInspectable const& sender,
                        Microsoft::UI::Xaml::Input::KeyRoutedEventArgs const& e);

private:
    // Submit the current input as a navigation. Stub for now — wires into
    // BrowserCommandController once the C++/WinRT binding lands.
    void SubmitCurrent();
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct Omnibar : OmnibarT<Omnibar, implementation::Omnibar> {};
}
