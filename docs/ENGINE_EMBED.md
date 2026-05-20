# Engine embed policy

Chrome must not link or load **system** web engines in CI or release paths. Each shell must use the **pinned** WebKit (or WPE-Android) build from this repository's matrix (`config/webkit-build-matrix.json`).

## Platform matrix

| Platform | Forbidden | Required |
|----------|-----------|----------|
| **Windows** | WebView2, unauthorized `windows-min` | `WKView` + `webkitium_host.dll` + `build-webkit --win`; WinUI `WebKitViewHost` |
| **macOS** | System `WebKit.framework` without pin path | In-process `WKWebView` from `WEBKIT_FRAMEWORK_PATH` / `DYLD_FRAMEWORK_PATH`, or `WEBKIT_MINIBROWSER` fallback |
| **iOS** | Simulator/device system WebKit without embedded frameworks | `WebKit.framework` + `JavaScriptCore.framework` copied into `Webkitium.app/Frameworks` via `scripts/ios_embed_webkit_frameworks.sh`, then in-process `WKWebView` |
| **Android** | `android.webkit.WebView` | `WPEView` + `WPEVIEW_AAR` from wpe-android `:wpeview:assembleDebug` |
| **Linux** | apt `libwebkitgtk-*`, workflow `linux-ci.yml` | `WEBKIT_GTK_BUILD` → pkg-config from pinned GTK port only |

## Environment variables

| Variable | Platform | Purpose |
|----------|----------|---------|
| `WEBKIT_GTK_BUILD` | Linux | Path to `WebKitBuild/GTK/Debug` (pkg-config) |
| `WEBKIT_FRAMEWORK_PATH` | macOS | Directory containing built `WebKit.framework` |
| `DYLD_FRAMEWORK_PATH` | macOS | Runtime load of pinned frameworks |
| `WEBKIT_MINIBROWSER` | macOS | Fallback: path to built `MiniBrowser` binary |
| `WPEVIEW_AAR` | Android | Path to `wpeview-*-debug.aar` |
| `WEBKITIUM_LAUNCH_URL` | All shells | CI/harness seed URL (e.g. `https://en.wikipedia.org`) |
| `WebKitSrc` / `WebKitBuild` | Windows | MSBuild properties for `WebKitHost` link + copy |

## CI release workflows

| Workflow | Bundles `engine/` + `chrome/` |
|----------|-------------------------------|
| `windows-release` | Yes |
| `macos-release` | Yes |
| `ios-release` | Yes |
| `android-release` | Yes |
| `linux-gtk-build` | Yes |

**Deleted:** `linux-ci.yml` (compiled chrome against distro WebKitGTK).

**GUI proof:** `browser-shell-screenshots` (manual `workflow_dispatch`) — builds or requires prebuilt engine trees on self-hosted runners, loads Wikipedia, asserts blue lock + non-empty content region.

## Local launch

```bash
scripts/run_chrome_with_engine.sh <platform> [engine-root]
# platform: windows | macos | linux-gtk
```

See per-platform `chrome/<platform>/README.md`.

## Honesty notes

- **Blue lock** on all platforms is currently driven by chrome URL state (`https://` prefix), not engine TLS APIs — see [`CHROME_PLATFORM_REVIEW.md`](CHROME_PLATFORM_REVIEW.md).
- **macOS/iOS `WKWebView`** loads the **built** `WebKit.framework` when paths/embed are set; it is not the same as shipping Safari's system WebKit, but it is not yet the Windows-style `WKView` C host.
- Historical incident record (pre-recovery): [`AGENT_AUDIT.md`](../AGENT_AUDIT.md) — do not treat as current wiring.
