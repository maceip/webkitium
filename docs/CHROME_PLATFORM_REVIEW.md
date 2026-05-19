# Chrome × pinned WebKit — static platform review

Last updated from repo state on `master`. This is an **honest** wiring review for self-hosted GUI builds and the **blue HTTPS lock** in chrome. It is not a marketing checklist.

## Summary matrix

| Platform | Engine in chrome window? | CI bundle (`*-release`) | Screenshot workflow | Blue lock truth |
|----------|--------------------------|-------------------------|---------------------|-----------------|
| **Windows** | Yes — `WKView` HWND in WinUI (`WebKitHost` + `WebKitViewHost`) | `windows-release` → engine + WinUI | Full WebKit build + shell | Lock tracks **polled** `WKPage` URL (`https://` prefix); not `WKPage` TLS API |
| **Linux GTK** | Yes — `webkit6::WebView` when `WEBKIT_GTK_BUILD` set | `linux-gtk-build` | Requires prebuilt GTK tree on runner | Lock from **active tab** `WebView.uri()` on load commit/finish |
| **Android** | Yes — `WPEView` when `WPEVIEW_AAR` set | `android-release` | **Was broken** (no AAR); must match android-release steps | Lock from **chrome URL string** on navigation callbacks |
| **macOS** | **No** — placeholder + **MiniBrowser** subprocess | `macos-release` bundles MiniBrowser | Chrome + MiniBrowser on runner; **no Wikipedia in shell** | Lock from **tab model URL** (`https://` prefix), not engine TLS |
| **iOS** | **No** — placeholder; sandbox blocks engine spawn | `ios-release` (engine bundle) | **Chrome-only** simulator shot | Same URL-prefix lock; **no fork in window** |

**Product bar:** A passing screenshot with a blue lock is **not** sufficient unless the **same window** shows page content from the pinned engine. Windows and Linux can meet that; macOS/iOS/Android CI must be read with the matrix above.

---

## Windows (`chrome/windows`)

### Wiring (good)

- `WebKitHost.dll` — `WKView` / `WKPage` C API (`WebKitHost.cpp`).
- WinUI `WebKitViewHost` parents native HWND; `MainWindow` loads via `LoadUrl`, polls URL/title every 400 ms.
- Build: `WebKitSrc` + `WebKitBuild` MSBuild properties; copies `WebKit.dll` + deps next to app.
- CI: `windows-release`, `browser-shell-screenshots` windows job build full `--win` tree then `dotnet build`.

### Smell tests / gaps

1. **Lock is URL-prefix only** (`MainWindow.xaml.cs`) — not `WKPageGetTLSInfo` or equivalent. A `https://` typo or redirect to `http://` after paint may lie until next poll.
2. **No navigation callback** — polling only; back/forward/lock can lag up to one timer tick.
3. **WebGPU** — separate probe workflow; shell build does not prove Dawn green.
4. **Screenshot does not assert lock** — full-desktop capture; should add `ci_assert_https_chrome_lock.py` on the crop of the URL bar region.

### Obviously broken if…

- `WebKit.dll` missing beside `Webkitium.exe` → `CoreReady` false, empty content, lock hidden.
- `windows-min` or WebView2 reintroduced (removed; guard in review).

---

## Linux GTK (`chrome/linux`)

### Wiring (good)

- `build.rs` **hard-fails** without `WEBKIT_GTK_BUILD` (no distro WebKitGTK).
- `window.rs` — per-tab `webkit6::WebView`, lock CSS on `.secure-lock` from `update_lock_icon(uri)` on `LoadEvent::Committed|Finished`.
- `WEBKITIUM_LAUNCH_URL` seeds first navigation (CI Wikipedia).
- CI: `linux-gtk-build` bundles; screenshot job requires `NG_LINUX_GTK_WEBKIT_SRC` tree on runner.

### Smell tests / gaps

1. Lock still **scheme-based** (`https://` prefix), not `webkit_web_view_get_tls_info` if exposed in bindings.
2. Runner must **pre-build** GTK port — screenshot job does not compile WebKit (by design, 2h+); fails fast if tree missing.
3. Harness tests under `harness_linux/` remain `#[ignore]` until engine + binary on PATH.

### Obviously broken if…

- `WEBKIT_GTK_BUILD` points at Release while chrome built Debug (pkg-config mismatch).
- Xvfb/software GL env vars wrong → blank WebView, screenshot passes chrome only.

---

## Android (`chrome/android`)

### Wiring (good)

- Gradle **requires** `WPEVIEW_AAR` — no silent WebView fallback.
- `createWpeEngineView` → `WPEView` + `WPEViewClient` for URL updates.
- `android-release`: wpe-android `assembleDebug` + `:wpeview:assembleDebug`, then chrome APK, tarball.

### Smell tests / gaps

1. **Lock follows chrome `url` state**, not a dedicated WPE security callback (verify WPE API when available).
2. **`browser-shell-screenshots` android job** previously ran `./gradlew assembleDebug` **without** engine → **guaranteed failure** or would have needed a stub (there is none).
3. Device Farm fuzz test does not assert Wikipedia or lock color — artifact grab only.

### Obviously broken if…

- `WPEVIEW_AAR` unset locally or in CI.
- Chrome APK without matching engine ABI in bundle.

---

## macOS (`chrome/macos`)

### Wiring (interim — does not meet embed bar)

- **No** in-process `WKView` / `WebKit.framework` view in chrome.
- `TabEngineHost` updates tab URL and calls `PinnedEngineLaunch.open(url:)` → external **MiniBrowser**.
- `WebContentArea` is a **placeholder** (“Content runs in MiniBrowser…”).
- Lock in `URLFieldView` — `isSecure` = `selectedTab?.url.hasPrefix("https://")`.

### Smell tests / gaps

1. Screenshot shows **Safari-like chrome** + blue lock on seed/https URL **without** Wikipedia rendered in the content pane.
2. **`WEBKITIUM_LAUNCH_URL`** was ignored by macOS (fixed: `applyCILaunchURLIfPresent()` on window appear).
3. Two windows (chrome + MiniBrowser) — screencapture may not include both.
4. Long-term: same pattern as Windows (`WebKitHost`-style) or in-process `WKView` on macOS port.

### Obviously broken if…

- `WEBKIT_MINIBROWSER` / `NG_MACOS_WEBKIT_SRC` MiniBrowser missing on runner.
- User believes screenshot proves fork render **inside** chrome.

---

## iOS (`chrome/ios`)

### Wiring (stub)

- No `import WebKit` / `WKWebView` in tree (good).
- `PinnedEngineLaunch` — log only; cannot spawn engine from app sandbox.
- `WEBKITIUM_LAUNCH_URL` handled in `iOSRootView` for tab URL / lock only.
- Simulator screenshot = **chrome UI**, not pinned MobileMiniBrowser in-process.

### Smell tests / gaps

1. Job title “chrome only” is correct; **do not** claim engine embed proof.
2. Blue lock on default seed tabs (`https://…`) without any engine load.

### Path to honest proof

- In-process embed using engine artifacts from `ios-release` bundle (WK API or hosted web view from **built** framework, not system).

---

## Blue lock — cross-cutting

| Implementation | Engine TLS? | Acceptable for CI “fork proof”? |
|----------------|-------------|----------------------------------|
| Windows / Linux / Android / macOS / iOS | **No** — `https://` on URL string | **Only** if same build also proves engine pixels in content area (Windows/Linux/Android can; macOS/iOS cannot today) |

**Recommendation:** Add engine security callbacks when the port exposes them; until then CI should use:

1. Bundled `engine/` in artifact manifest (`BUNDLE_MANIFEST.json`).
2. Screenshot + optional `scripts/ci_assert_https_chrome_lock.py` (chrome lock **visible**).
3. Windows/Linux: assert non-empty content / title from engine poll where possible.

---

## CI workflows map

| Workflow | Produces GUI + engine bundle? | Notes |
|----------|------------------------------|-------|
| `windows-release` | Yes | WebGPU flags from matrix |
| `linux-gtk-build` | Yes | Self-hosted ARM64 Linux |
| `macos-build.yml` / release | Yes | MiniBrowser + chrome |
| `ios-build.yml` | Engine bundle; chrome separate | Embed WIP |
| `android-release` | Yes | APKs + tar |
| `browser-shell-screenshots` | Partial | Windows/Linux real; macOS/iOS misleading for content; android fixed to require WPE |
| ~~`linux-ci.yml`~~ | **Deleted** | Was distro WebKitGTK lie |

---

## Priority fixes (engineering)

1. **macOS/iOS** — in-process view host (track Windows `WebKitHost`).
2. **Lock** — wire to engine TLS / secure-origin APIs per port.
3. **Screenshots** — run `ci_assert_https_chrome_lock.py`; fail macOS/iOS jobs if claiming “Wikipedia in shell” without pixel check.
4. **Android screenshots** — always build/locate `wpeview` AAR before chrome (same as `android-release`).
5. **Harness** — un-ignore Linux/Windows harness when `WEBKITIUM_LAUNCH_URL` + bundle on PATH.

See also: `docs/ENGINE_EMBED.md`, `AGENT_AUDIT.md`, `chrome/README.md`.
