# MiniBrowser-level functional gaps

What is missing from each shell to reach baseline browser usability — i.e., the level of functionality WebKit's `MiniBrowser` ships out of the box.  Reference is the Apple Win port we already build through `webkit/patches/windows/`; mobile/macOS targets calibrate against equivalent first-party browsers (Safari, Chrome) at the bare-minimum interaction layer.

This is the "what's left after wired-but-inactive" companion to the
controllers landed in this turn (extensions / sync / webauthn surfaces in
`browser/{extensions,sync,webauthn}/*BridgeC.{h,cc}` plus per-shell
holders in `chrome/<platform>/`).

## Wired today (this commit)

| Service | Status | Activation gate |
|---|---|---|
| `browser/color/` palette | Active across all shells, used by every rendered surface | n/a |
| `browser/extensions/` | Wired-but-inactive; `WkExtensionRegistry` is empty until `install()` | needs `chrome.runtime` IPC + manifest loader |
| `browser/sync/` | Stub today; controller surface exists but `LoopbackSyncServer` not yet linked into shell sidecars | needs the protobuf chain + a peer discovery story |
| `browser/webauthn/` | Wired (controller constructed); inactive provider always rejects | needs platform-specific authenticator binding (Windows Hello / Touch ID / Android BiometricPrompt) |

## Tier 1 — without these, the app is not usable as a browser

| Gap | Where it fits | Status |
|---|---|---|
| **Real `WebView` / WK content host** | `chrome/<platform>/.../*Tab.*` | ✅ Windows: WebView2 fully configured. macOS: `WKWebView` via `NSViewRepresentable`. Linux: WebKitGTK with cookie persistence. Android: `android.webkit.WebView` via Compose `AndroidView`. |
| **Address-bar URL → navigation dispatch** | omnibar → active tab `LoadRequest` | ✅ All four shells: omnibar submit → WebView navigate with URL normalization and search fallback. |
| **Tab create / close** | `Ctrl+T` / `Ctrl+W` / `Cmd+T` / `Cmd+W` | ✅ Windows: `Ctrl+T`/`Ctrl+W` wired. macOS: `Cmd+T`/`Cmd+W` via menu commands. Linux: `Ctrl+T`/`Ctrl+W` via GTK shortcuts. Android: single-tab with back-press navigation. |
| **Back / forward / reload buttons functional** | wired into the active WebView's nav stack | ✅ All shells: toolbar buttons and keyboard shortcuts wired to WebView back/forward/reload. |
| **Cookie + LocalStorage persistence** | per-WebView data store | ✅ Windows: `CoreWebView2` default data store. macOS: `WKWebsiteDataStore.default()`. Linux: SQLite cookie jar via `WebKitCookieManager`. Android: `CookieManager` + `domStorageEnabled`. |
| **HTTP error page rendering** | styled error page when nav fails | ✅ All shells render a branded dark error page with the failed URL, error message, and a "Go back" button. |

## Tier 2 — expected, ~~missing today~~ implemented

| Gap | Where it fits | Status |
|---|---|---|
| **Right-click context menu** | per `design/components/context-menu/SPEC.md` | ✅ Windows: WebView2 default context menus enabled. macOS: WKWebView native context menu. Linux: WebKitGTK default context menu. Android: long-press hit-test with toast. |
| **Find-in-page (Ctrl+F)** | find bar + WebView find | ✅ Windows: `Ctrl+F` → `FindBar` overlay → `window.find()`. macOS: `Cmd+F` → revealer find bar. Linux: `Ctrl+F` → GtkRevealer + `WebKitFindController`. Android: search icon → find bar + `findAllAsync()`. |
| **DevTools / Inspector** | F12 / Develop menu | ✅ Windows: `F12` → `CoreWebView2.OpenDevToolsWindow()`. macOS: WKWebView inspector (Develop menu). Linux: `F12` → `WebKitWebInspector.show()`. |
| **Download manager** | event hookup + notification | ✅ Windows: `CoreWebView2.DownloadStarting` event. macOS: WKDownload delegate. Linux: WebKitGTK `decide-policy` download. Android: `DownloadListener` with toast notification. |
| **Print to PDF** | system print dialog | ✅ Windows: `Ctrl+P` → `CoreWebView2.PrintToPdfAsync()` with file picker. macOS: `Cmd+P` menu command. Linux: `Ctrl+P` → `WebKitPrintOperation`. Android: `PrintManager` + `createPrintDocumentAdapter()`. |
| **Zoom (Ctrl+± / pinch)** | WebView zoom controls | ✅ Windows: `Ctrl++`/`Ctrl+-`/`Ctrl+0` → `WebView2.ZoomFactor`. macOS: `Cmd++`/`Cmd+-`/`Cmd+0` menu commands. Linux: `Ctrl++`/`Ctrl+-`/`Ctrl+0` → `webkit_web_view_set_zoom_level()`. Android: pinch zoom + toolbar `ZoomIn`/`ZoomOut` buttons. |
| **History pane** | sidepanel section | ✅ macOS: sidebar history list with click-to-navigate. Android: toolbar history icon → scrollable history panel. Core: `BrowserStateModel::addHistoryEntry()` + deque. |
| **Bookmarks** | sidepanel section | ✅ macOS: sidebar bookmark list with add/remove. Windows: `Ctrl+D` bookmark flyout. Android: toolbar bookmark icon + bookmarks panel. Core: `BrowserStateModel::addBookmark()` + vector. |
| **Suggestion dropdown for the omnibar** | typing in the input shows suggestions | ✅ Windows: existing `Suggestions` ListView with stub data. macOS: `OmnibarSuggestion` list with prefix filtering. |
| **Tab restore** (Ctrl+Shift+T) | `BrowserStateModel` persists closed-tab stack | ✅ Windows: `Ctrl+Shift+T` restores from `_closedTabStack`. macOS: `Cmd+Shift+T` via menu command. Core: `BrowserStateModel::restoreLastClosedTab()` from `m_closedTabs` deque (max 25). |
| **Per-site permissions UI** | camera / mic / location prompts | ✅ Windows: `CoreWebView2.PermissionRequested` → `ContentDialog` (Allow/Deny/Dismiss). macOS: `WKWebView` native permission prompts. Linux: `WebKitPermissionRequest` with deny-by-default. Android: `PermissionRequest.deny()` + `GeolocationPermissions.Callback` with toast notification. |

## Tier 3 — productivity / parity, deferred

| Gap | Where it fits |
|---|---|
| Tab groups / spaces | `BrowserStateModel` has `TabStripMode` but no group concept |
| Picture-in-picture | per-tab WebView feature |
| Translate panel | per-tab WebView integration |
| Reader mode | needs reader extractor |
| Drag-and-drop tab reorder | TabView already supports it on Windows; not handled on others |
| Multi-window / Workspaces | `BrowserCommandController.newWindow` exists, no UI to invoke |

## Wiring gaps for the controllers we just landed

These are concrete TODOs to move each "wired-but-inactive" service to "active":

### Extensions
- [ ] Manifest V3 loader: read `manifest.json` from disk, build `ng::ExtensionManifest`, call `ExtensionRegistry::install()`.
- [ ] `chrome.runtime.sendMessage` plumbing: bridge `ExtensionRuntime::dispatch` to a per-WebView IPC channel.
- [ ] Settings → Extensions page (currently absent on every shell) listing installed manifests.
- [ ] Background page / service worker host (long-lived JS context per extension).

### Sync
- [ ] Replace `SyncBridgeC.cc` stub with the LoopbackSyncServer-backed implementation; pull the protobuf chain into Windows sidecar / macOS SwiftPM target / Android JNI cmake.
- [ ] First-run device pairing flow (QR code, OS-level paired-device API).
- [ ] Settings → Paired devices reads from the bridge once non-stub.

### WebAuthn
- [ ] Replace `InactivePlatformProvider` with platform-real:
  - Windows: `IDXGIAuthenticator` / `WebAuthn.dll` (Win 19H1+).
  - macOS / iOS: `ASAuthorizationController` for passkey assertion.
  - Android: `androidx.credentials.CredentialManager`.
- [ ] WebAuthn ceremony UI is **out-of-process** per `design/components/authenticator/SECURITY_BOUNDARY.md`; needs a separate window in each shell.
- [ ] Settings → Passwords (already a stub page on Windows) reads counts from the bridge.

## Cross-cutting

- **No process model**: WebKit Win runs `WebKit{Web,Network,GPU}Process.exe` as separate processes.  Our shells host an in-process WebView2 (or WKWebView) directly.  Some features (like the WebGPU sandbox) only matter when there's a real process split — defer until we host the WebKit port itself.
- **No telemetry / logging spine** beyond `Log.cpp` on the Windows side and `OSLog` on macOS.  We haven't decided on a unified logging story.
- **No update channel**: how the app self-updates is undefined.  Likely platform-specific (MSIX, App Store, Play Store, Flatpak).

## What's NOT a gap

- Branding tokens / palette: ✅ done, all five shells use the same OKLCH algorithm.
- Layout shell: ✅ described in `design/components/shell/SPEC.md`; macOS implemented as `NavigationSplitView`, Windows partially (top strip exists, sidepanel pending).
- WebGPU on Windows: not part of MiniBrowser baseline; tracked separately under `webkit/patches/windows/00*-windows-*webgpu*.patch`.
- Theming runtime: ✅ `PaletteProvider` swap on each shell.
