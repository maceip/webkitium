// Settings -> Paired devices page.  Read-only stub.  Real data source
// lands when the C++/WinRT bridge for browser/sync/LoopbackSyncServer is
// written.

#pragma once

#include "SettingsPairedDevicesPage.g.h"

namespace winrt::webkitium::implementation {

struct SettingsPairedDevicesPage : SettingsPairedDevicesPageT<SettingsPairedDevicesPage> {
    SettingsPairedDevicesPage() { InitializeComponent(); }
};

}  // namespace winrt::webkitium::implementation

namespace winrt::webkitium::factory_implementation {
struct SettingsPairedDevicesPage : SettingsPairedDevicesPageT<SettingsPairedDevicesPage, implementation::SettingsPairedDevicesPage> {};
}
