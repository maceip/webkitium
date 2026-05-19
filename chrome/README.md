# Platform chrome (`chrome/`)

Native UI around `browser/` FFI. Each platform release tarball contains `engine/` + `chrome/` + `BUNDLE_MANIFEST.json`.

| Directory | Engine |
|-----------|--------|
| `windows/` | WKView via `WebKitHost` |
| `macos/` | Pinned `MiniBrowser` (`WEBKIT_MINIBROWSER`) |
| `ios/` | Pinned engine app in bundle (in-process embed WIP) |
| `android/` | WPEView + engine `wpeview` AAR |
| `linux/` | WebKitGTK from `WEBKIT_GTK_BUILD` only |

No distro WebKitGTK, no `WKWebView`, no `android.webkit.WebView`, no WebView2.

See `docs/ENGINE_EMBED.md`.
