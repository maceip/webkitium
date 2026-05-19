# Platform chrome (`chrome/`)

Native UI shells around the portable C++ layer in `browser/`. Each platform CI job produces a **bundle tarball** (`engine/` + `chrome/` + `BUNDLE_MANIFEST.json`) via `scripts/bundle_webkitium_platform.sh`.

| Directory | UI | Engine in chrome |
|-----------|-----|------------------|
| `windows/` | WinUI 3 | **WKView** via `WebKitHost` + pinned `build-webkit --win` |
| `macos/` | SwiftUI | `WKWebView` with `WEBKIT_FRAMEWORK_PATH` → pinned `WebKit.framework` |
| `ios/` | SwiftUI | `WKWebView` (simulator); bundle includes engine `MiniBrowser.app` + `Webkitium.app` |
| `android/` | Compose | **WPEView** from engine `wpeview-*.aar` (`WPEVIEW_AAR`) |
| `linux/` | gtk4-rs | **WebKitGTK** from `WEBKIT_GTK_BUILD` (pinned GTK port) |

Local run: `scripts/run_chrome_with_engine.sh <platform> [engine-root]`

Policy: `docs/ENGINE_EMBED.md`
