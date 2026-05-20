# MiniBrowser-level functional gaps

What is still missing from each shell to reach baseline browser usability — i.e., the level of functionality WebKit's `MiniBrowser` ships out of the box. Reference is the Apple Win port we build through `webkit/patches/windows/`; other OS targets calibrate against Safari/Chrome at the bare-minimum interaction layer.

Companion docs: [`ENGINE_EMBED.md`](ENGINE_EMBED.md) (what engine each shell may load), [`CHROME_PLATFORM_REVIEW.md`](CHROME_PLATFORM_REVIEW.md) (CI + screenshot honesty).

## Engine embed status (current)

| Platform | Content host | Forbidden in CI/release |
|----------|--------------|-------------------------|
| **Windows** | `WKView` via `WebKitHost` / WinUI `WebKitViewHost` | WebView2, `chrome/windows-min/` |
| **macOS** | In-process `WKWebView` from pinned `WebKit.framework` when `WEBKIT_FRAMEWORK_PATH` is set; else external `MiniBrowser` | System `/System/Library/Frameworks/WebKit.framework` without pin |
| **iOS** | In-process `WKWebView` after `scripts/ios_embed_webkit_frameworks.sh` copies built frameworks into `.app` | System WebKit without embedded fork frameworks |
| **Android** | `WPEView` from engine `wpeview-*.aar` (`WPEVIEW_AAR` required) | `android.webkit.WebView` (Chromium) |
| **Linux** | `webkit6::WebView` linked via `WEBKIT_GTK_BUILD` pkg-config | apt `libwebkitgtk-*` / `linux-ci.yml` |

GUI proof: workflow `browser-shell-screenshots` loads `https://en.wikipedia.org` and runs `ci_assert_https_chrome_lock.py` + `ci_assert_engine_content.py` where applicable.

## Wired today

| Service | Status | Activation gate |
|---|---|---|
| `browser/color/` palette | Active across all shells | n/a |
| `browser/extensions/` | Wired-but-inactive; empty registry until `install()` | needs `chrome.runtime` IPC + manifest loader |
| `browser/sync/` | Stub; controller exists, loopback server not in shells | needs protobuf chain + peer discovery |
| `browser/webauthn/` | Wired; inactive provider rejects | needs platform authenticator (Hello / Touch ID / CredentialManager) |
| **URL normalization** | Active via `browser/url/` FFI on all platforms | n/a |
| **macOS/iOS navigation** | `TabEngineHost` + in-process or MiniBrowser fallback | `WEBKITIUM_LAUNCH_URL` for CI seed URL |

## Tier 1 — without these, the app is not usable as a browser

| Gap | Where it fits | Notes |
|---|---|---|
| **TLS-backed lock indicator** | Omnibar on every shell | Today lock is `https://` URL-prefix on chrome state; not engine TLS / secure-origin API. |
| **Address-bar URL → navigation dispatch** | omnibar Enter → active tab load | Partially wired on macOS/iOS/Android/Linux/Windows; polish and error paths remain. |
| **Tab create / close** | Desktop accelerators, mobile "+" | Windows/Linux/macOS have UI; some handlers still thin. |
| **Back / forward / reload** | Active WebView nav stack | Toolbar wired; in-process hosts use engine back/forward where embed exists. |
| **Cookie + LocalStorage persistence** | Per-profile data store | Not profile-scoped in shell yet on most platforms. |
| **HTTP error page rendering** | Error surface on nav failure | Failures can look like blank/loading. |

## Tier 2 — expected, missing today

| Gap | Where it fits |
|---|---|
| **Right-click context menu** | per `design/components/context-menu/SPEC.md` |
| **Find-in-page (Ctrl+F)** | Linux has `FindController`; others partial |
| **DevTools / Inspector** | MiniBrowser has it; shells mostly don't expose |
| **Download manager** | FFI hooks exist on some platforms; UI incomplete |
| **Print to PDF** | not started |
| **Zoom (Ctrl+± / pinch)** | partially stubbed on macOS |
| **History / bookmarks UI** | sidepanel / sheets partial |
| **Suggestion dropdown** | Linux wired; others partial |
| **Tab restore (Ctrl+Shift+T)** | not persisted |
| **Per-site permissions UI** | not surfaced |

## Tier 3 — productivity / parity, deferred

| Gap | Where it fits |
|---|---|
| Tab groups / spaces | `TabStripMode` exists, groups partial on macOS |
| Picture-in-picture | per-tab feature |
| Translate / Reader | stubs in chrome |
| Drag-and-drop tab reorder | Windows TabView; others partial |
| Multi-window | `BrowserCommandController.newWindow` exists, thin UI |

## Wiring gaps for wired-but-inactive controllers

### Extensions
- [ ] Manifest V3 loader → `ExtensionRegistry::install()`
- [ ] `chrome.runtime.sendMessage` IPC per WebView
- [ ] Settings → Extensions page
- [ ] Background / service worker host

### Sync
- [ ] Real `SyncBridge` + LoopbackSyncServer in shells
- [ ] Device pairing flow
- [ ] Settings → Paired devices

### WebAuthn
- [ ] Platform providers (Hello, ASAuthorization, CredentialManager)
- [ ] Out-of-process ceremony UI per `design/components/authenticator/SECURITY_BOUNDARY.md`
- [ ] Settings → Passwords from bridge

## Cross-cutting

- **Process model**: WebKit-for-Windows uses `WebKit{Web,Network,GPU}Process.exe`. Win/macOS/iOS shells may host an in-process view (`WKView` / `WKWebView` from **pinned** builds). WebGPU sandbox semantics still tracked under `webkit/patches/windows/`.
- **Long-term embed**: Windows uses C API `WKView` host; macOS/iOS may move to port-native `WKView` host like `chrome/windows/WebKitHost/` instead of `WKWebView` wrapper.
- **No unified telemetry spine** beyond platform logs.
- **No update channel** defined (MSIX, App Store, Play, Flatpak).

## What's NOT a gap

- Branding / palette: all shells use `browser/color/`.
- Layout shell: `design/components/shell/SPEC.md`; macOS `NavigationSplitView`, Windows WinUI tab strip.
- WebGPU on Windows: separate program — `docs/WEBGPU_PROGRAM.md`, not MiniBrowser baseline.
- Theming: `PaletteProvider` per shell.
- **Deleted anti-patterns:** `linux-ci.yml`, `chrome/windows-min/`, WebView2 in WinUI, apt WebKitGTK for release Linux builds.
