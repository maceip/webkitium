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

| Gap | Where it fits | Notes |
|---|---|---|
| **Real `WebView` / WK content host** | `chrome/<platform>/.../*Tab.*` currently shows the placeholder text "Web content goes here" | Windows: `WebView2` (already in MainWindow.xaml as `PART_WebView` but unconfigured).  macOS: `WKWebView` via SwiftUI `NSViewRepresentable`.  Android: WebView/WebKit Android.  iOS: `WKWebView`. |
| **Address-bar URL → navigation dispatch** | omnibar `KeyDown(Enter)` → BrowserCommandController → active tab `LoadRequest` | `BrowserCommandController.navigateActiveTab()` exists; not yet bridged. |
| **Tab create / close** | `Ctrl+T` / `Ctrl+W` keyboard accelerators on desktop, "+" button on mobile | Stubs in MainWindow: `OnAddTab` / `OnTabClose` exist on Windows but call into nothing.  No bridge yet. |
| **Back / forward / reload buttons functional** | wired into the active WebView's nav stack | Toolbar buttons exist on every shell; `Click` handlers are no-ops. |
| **Cookie + LocalStorage persistence** | per-WebView data store | Windows: `CoreWebView2Environment` + a per-profile UserDataFolder.  macOS/iOS: `WKWebsiteDataStore`.  Android: WebView default.  None set up. |
| **HTTP error page rendering** | a blank-white placeholder when nav fails | Today there is no error-page surface; failures look identical to "loading" (silent). |

## Tier 2 — expected, missing today

| Gap | Where it fits |
|---|---|
| **Right-click context menu** | per `design/components/context-menu/SPEC.md`; NO platform shell renders one yet |
| **Find-in-page (Ctrl+F)** | not started |
| **DevTools / Inspector** | Apple Win MiniBrowser has it; our shells don't expose it |
| **Download manager** | no UI surface, no event hookup |
| **Print to PDF** | system print dialog dispatch |
| **Zoom (Ctrl+± / pinch)** | not bound |
| **History pane** | sidepanel section in SPEC, not implemented |
| **Bookmarks** | sidepanel section in SPEC, not implemented |
| **Suggestion dropdown for the omnibar** | typing in the input shows nothing |
| **Tab restore** (Ctrl+Shift+T) | `BrowserStateModel` does not persist closed-tab stack |
| **Per-site permissions UI** | camera / mic / location prompts are not surfaced |

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
