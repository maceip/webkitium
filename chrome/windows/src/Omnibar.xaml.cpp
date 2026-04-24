#include "pch.h"
#include "Omnibar.xaml.h"
#if __has_include("Omnibar.g.cpp")
#include "Omnibar.g.cpp"
#endif

using namespace winrt;
using namespace Microsoft::UI::Xaml;
using namespace Microsoft::UI::Xaml::Input;
using namespace Windows::System;

namespace winrt::webkitium::implementation {

Omnibar::Omnibar() {
    InitializeComponent();
}

void Omnibar::OnInputGotFocus(IInspectable const&, RoutedEventArgs const&) {
    // Spec: on focus, select all so the next keystroke replaces the origin.
    auto input = PART_Input();
    if (input) {
        input.SelectAll();
    }
    // Focus ring upgrade: thicken the pill border to BorderFocus.
    auto pill = PART_Pill();
    if (pill) {
        pill.BorderThickness({ 2, 2, 2, 2 });
        pill.BorderBrush(
            Application::Current().Resources()
                .Lookup(box_value(L"BorderFocus"))
                .as<Media::Brush>());
    }
}

void Omnibar::OnInputLostFocus(IInspectable const&, RoutedEventArgs const&) {
    auto pill = PART_Pill();
    if (pill) {
        pill.BorderThickness({ 1, 1, 1, 1 });
        pill.BorderBrush(
            Application::Current().Resources()
                .Lookup(box_value(L"BorderSubtle"))
                .as<Media::Brush>());
    }
}

void Omnibar::OnInputKeyDown(IInspectable const&, KeyRoutedEventArgs const& e) {
    // Per spec:
    //  - Enter submits
    //  - Esc restores origin (stub: drops focus for now)
    //  - Tab accepts inline completion when present (no inline completion yet)
    switch (e.Key()) {
    case VirtualKey::Enter:
        SubmitCurrent();
        e.Handled(true);
        break;
    case VirtualKey::Escape:
        this->Focus(FocusState::Programmatic);  // drop focus
        e.Handled(true);
        break;
    default:
        break;
    }
}

void Omnibar::SubmitCurrent() {
    // Stub. When wired to browser/tabs/, this will call
    // BrowserCommandController::navigateActiveTab(text). For now we just
    // clear focus so the pill visibly "commits."
    this->Focus(FocusState::Programmatic);
}

}  // namespace winrt::webkitium::implementation
