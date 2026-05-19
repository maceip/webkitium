# Engine embed policy

Webkitium chrome must not use **system** web engines:

| Platform | Forbidden | Canonical path |
|----------|-----------|----------------|
| Windows | WebView2 (Chromium) | `WKView` via `chrome/windows/WebKitHost/` + pinned `build-webkit --win` |
| macOS | System WebKit without `WEBKIT_FRAMEWORK_PATH` | `WKWebView` + `DYLD_FRAMEWORK_PATH` → pinned `WebKit.framework` |
| iOS | System WebKit without bundle path | `WKWebView` + engine `MiniBrowser.app` in CI bundle |
| Android | `android.webkit.WebView` (Chromium) | `org.wpewebkit.wpeview.WPEView` + `wpeview-*.aar` from engine build |
| Linux | apt `libwebkitgtk-6.0` | `webkit6` crate + `WEBKIT_GTK_BUILD` pkg-config from pin |

## Dawn / WebGPU on Windows builds

Windows CI keeps **`--webgpu`** via `enableWebgpuViaBuildWebkit` in `config/webkit-build-matrix.json` (same as before). Dawn compat belongs in `webkit/patches/windows/`, not in local stub `.cpp` files on a laptop.

Disabling WebGPU in `build-webkit` to “simplify” the shell path usually costs more than it saves: the EC2 runner and patch series are already set up for the full Windows engine build. Shell work (WKView, no WebView2) is separate from that.

## Scaffolding vs proof

- **Chrome scaffolding** (tabs, URL bar, FFI suggestions/bookmarks) should compile and run on every platform.
- **Screenshots / “it renders Wikipedia”** only count when the pixel source is the pinned WebKit build for that OS.
