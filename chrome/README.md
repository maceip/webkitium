# Platform chrome (`chrome/`)

Native UI around `browser/` FFI. Each platform **release** tarball contains `engine/` + `chrome/` + `BUNDLE_MANIFEST.json` (see `scripts/bundle_webkitium_platform.sh`).

| Directory | Pinned engine path |
|-----------|-------------------|
| `windows/` | `WKView` via `WebKitHost` (WinUI `WebKitViewHost`) |
| `macos/` | In-process `WKWebView` from built `WebKit.framework`, or `WEBKIT_MINIBROWSER` fallback |
| `ios/` | In-process `WKWebView` with embedded `WebKit.framework` in `.app`, or placeholder |
| `android/` | `WPEView` + engine `wpeview` AAR (`WPEVIEW_AAR`) |
| `linux/` | `webkit6::WebView` from `WEBKIT_GTK_BUILD` only |

## Forbidden in CI / release

- WebView2 (Windows)
- `android.webkit.WebView` (Chromium)
- apt / distro `libwebkitgtk` (Linux)
- System WebKit without `WEBKIT_FRAMEWORK_PATH` / embed script (macOS/iOS)
- `chrome/windows-min/` (removed)

`WKWebView` on macOS/iOS is allowed only when linked/loaded from **your** WebKit build, not the OS default framework.

## Docs

| Doc | Purpose |
|-----|---------|
| [`docs/ENGINE_EMBED.md`](../docs/ENGINE_EMBED.md) | Policy + env vars |
| [`docs/CHROME_PLATFORM_REVIEW.md`](../docs/CHROME_PLATFORM_REVIEW.md) | Wiring + CI honesty |
| [`docs/MINIBROWSER_GAPS.md`](../docs/MINIBROWSER_GAPS.md) | Feature gaps vs MiniBrowser |

## Local run

```bash
scripts/run_chrome_with_engine.sh <windows|macos|linux-gtk> [engine-root]
```

Optional: `WEBKITIUM_LAUNCH_URL=https://en.wikipedia.org` for CI-style seed navigation.
