# WebKitHost (`webkitium_host.dll`)

Native DLL that embeds **WebKit-for-Windows** (`WKView` / `WKPage`) for the WinUI shell. This is the only supported Windows content engine path — not WebView2, not a separate “min” executable.

## Build inputs

Requires a completed Apple Win port build:

- `WebKitSrc` — e.g. `C:\W\webkit-src`
- `WebKitBuild` — e.g. `C:\W\webkit-src\WebKitBuild\Debug`

Links `WebKit2.lib` and `JavaScriptCore.lib` from `$(WebKitBuild)\lib\`.

## Exports

Cdecl API in `WebKitHost.h`, consumed from C# via `Webkitium/FFI/WebKitHostBridge.cs`.
