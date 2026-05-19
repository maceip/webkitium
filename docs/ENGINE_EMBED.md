# Engine embed policy

Chrome must not link or load **system** web engines in CI or release paths.

| Platform | Forbidden | Required |
|----------|-----------|----------|
| Windows | WebView2 | `WKView` + `webkitium_host.dll` + pinned `build-webkit --win` |
| macOS | System `WebKit.framework` without `WEBKIT_FRAMEWORK_PATH` | In-process `WKWebView` from pinned build, or `WEBKIT_MINIBROWSER` fallback |
| iOS | `WKWebView` / system WebKit | Engine bundle + in-process embed (WIP) |
| Android | `android.webkit.WebView` | `WPEView` + `WPEVIEW_AAR` from wpe-android build |
| Linux | apt `libwebkitgtk-*` | `WEBKIT_GTK_BUILD` pkg-config from pin |

## CI

- **Deleted:** `linux-ci.yml` (built chrome against distro WebKitGTK — never wanted).
- **Platform builds:** `linux-gtk-build`, `macos-release`, `ios-release`, `android-release`, `windows-release` each bundle `engine/` + `chrome/`.

## Local

`scripts/run_chrome_with_engine.sh <platform> [engine-root]`
