# Webkitium — Windows shell

WinUI 3 chrome (`chrome/windows/Webkitium/`) hosting **WebKit-for-Windows** through `WKView`, not WebView2.

| Component | Role |
|-----------|------|
| `Webkitium.exe` | WinUI 3 shell (tabs, URL bar, bookmarks, find overlay) |
| `webkitium_core.dll` | Portable C++ (`browser/url/`, `browser/suggestions/`) |
| `webkitium_host.dll` | WKView embedder (`WebKitHost/`) linked against your pinned WebKit build |
| `WebKit*.dll`, `JavaScriptCore.dll`, … | Runtime from `build-webkit --win` at `WebKitBuild/Debug/bin/` |

## Prerequisites

- Windows 11 22H2+
- Visual Studio 2022 17.10+ (.NET Desktop + Desktop C++)
- .NET 8 SDK, Windows App SDK 1.6
- **Built WebKit-for-Windows** at `C:\W\webkit-src` (or set `/p:WebKitSrc` / `/p:WebKitBuild`)
- vcpkg integrated (`vcpkg integrate install`) for `BrowserCore` sqlite3

## Build

After `perl Tools\Scripts\build-webkit --debug --win` in the WebKit tree:

```cmd
cd chrome\windows
dotnet build Webkitium.sln -c Debug -p:Platform=x64 ^
  /p:WebKitSrc=C:\W\webkit-src ^
  /p:WebKitBuild=C:\W\webkit-src\WebKitBuild\Debug
```

The post-build step copies `webkitium_host.dll`, `webkitium_core.dll`, and WebKit runtime DLLs into the `Webkitium.exe` output folder.

## Run

```cmd
.\Webkitium\bin\x64\Debug\net8.0-windows10.0.19041.0\Webkitium.exe
```

Optional: `set WEBKITIUM_LAUNCH_URL=https://en.wikipedia.org` or `--profile-dir=<path>` for harness runs.

## Architecture notes

- Each tab owns a `WebKitViewHost` (WinUI `Grid`) that parents a native `WKView` HWND into the main window, positioned to the tab content area.
- Navigation state is polled from `WKPage` (back/forward/title/URL); there is no WebView2 / Chromium in this path.
- Find-in-page uses `WKPageRunJavaScriptInMainFrame` with the same injected controller pattern as before, but against our engine.

## CI

The `browser-shell-screenshots` Windows job on the `webkitium` self-hosted runner builds pinned WebKit, then this solution, then captures a desktop screenshot. That artifact only counts as “Webkitium on our WebKit” when this build path succeeds.

## Harness

Smoke tests under `harness_windows/` drive `Webkitium.exe` via UIAutomation. Set `WEBKITIUM_EXE` if the binary is not under the default `bin\x64\Debug\...` path.
