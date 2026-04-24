// Settings -> Passwords page.  Read-only stub with mock data shaped
// like WebAuthnController's event log.  Real event stream is wired in
// when the C++/WinRT bridge for browser/webauthn/ is written.

#pragma once

#include "SettingsPasswordsPage.g.h"

namespace winrt::webkitium::implementation {

struct SettingsPasswordsPage : SettingsPasswordsPageT<SettingsPasswordsPage> {
    SettingsPasswordsPage() { InitializeComponent(); }
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct SettingsPasswordsPage : SettingsPasswordsPageT<SettingsPasswordsPage, implementation::SettingsPasswordsPage> {};
}
