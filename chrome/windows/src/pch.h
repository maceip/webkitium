// Precompiled header for the webkitium Windows shell.
//
// Brings in C++/WinRT + WinUI 3 + Windows App SDK projections. Keep this
// lean — heavy STL headers belong in translation units that need them.

#pragma once

// Disable win32 API cruft the WinUI stack does not need and which
// collides with WinRT method names (e.g. GetCurrentTime on
// IStoryboard).  Must precede <windows.h>.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX

#include <windows.h>

// <winbase.h> defines GetCurrentTime as an alias for GetTickCount.
// WinRT's Microsoft.UI.Xaml.Media.Animation.IStoryboard.GetCurrentTime
// collides with that macro.  Undef here so the WinRT projection headers
// that follow see the real identifier.
#undef GetCurrentTime

#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>

#include <winrt/Microsoft.UI.Xaml.h>
#include <winrt/Microsoft.UI.Xaml.Controls.h>
#include <winrt/Microsoft.UI.Xaml.Controls.Primitives.h>
#include <winrt/Microsoft.UI.Xaml.Data.h>
#include <winrt/Microsoft.UI.Xaml.Input.h>
#include <winrt/Microsoft.UI.Xaml.Interop.h>
#include <winrt/Microsoft.UI.Xaml.Markup.h>
#include <winrt/Microsoft.UI.Xaml.Media.h>
#include <winrt/Microsoft.UI.Xaml.Media.Animation.h>
#include <winrt/Microsoft.UI.Xaml.Navigation.h>
