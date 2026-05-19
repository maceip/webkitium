# Webkitium — macOS shell

SwiftUI chrome around `browser/` FFI (suggestions, bookmarks, URL normalize).

**Content engine:** does **not** use system `WKWebView`. Tab content shows a placeholder until the pinned WebKit build from `webkit/patches/macos/` is embedded. Navigation state (URL, back/forward) is driven by `TabEngineHost` + FFI normalize for scaffolding.

## Build

```bash
cd chrome/macos
swift build
```

## Run

Open `.build/debug/Webkitium.app` or the `Webkitium` binary. Optional: `WEBKITIUM_LAUNCH_URL=https://example.com`.
