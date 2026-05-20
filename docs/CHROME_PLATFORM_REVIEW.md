# Chrome × pinned WebKit — platform review

**Last aligned with:** commit `0c665a5` (`master`). Honest wiring reference for self-hosted GUI builds, engine bundles, and the **blue HTTPS lock**.

## Summary matrix

| Platform | Engine in chrome window? | CI bundle | Screenshot workflow | Blue lock |
|----------|--------------------------|-----------|-------------------|-----------|
| **Windows** | Yes — `WKView` HWND (`WebKitHost` + `WebKitViewHost`) | `windows-release` | Full WebKit + WinUI build | Polled `WKPage` URL (`https://` prefix) |
| **Linux GTK** | Yes — `webkit6::WebView` + `WEBKIT_GTK_BUILD` | `linux-gtk-build` | Prebuilt GTK tree on runner | From `WebView.uri()` on load |
| **Android** | Yes — `WPEView` + `WPEVIEW_AAR` | `android-release` | WPE AAR + chrome APK; Device Farm capture | Chrome URL on navigation callbacks |
| **macOS** | Yes when `WEBKIT_FRAMEWORK_PATH` set — in-process `WKWebView` from pinned framework; else MiniBrowser fallback + placeholder | `macos-release` | `swift build -F` + `DYLD`; lock + content asserts | Tab URL prefix |
| **iOS** | Yes when frameworks embedded — in-process `WKWebView`; else placeholder | `ios-release` | Requires `NG_IOS_WEBKIT_PATH` + `ios_embed_webkit_frameworks.sh` | Tab URL prefix |

**CI gates:** `scripts/ci_assert_https_chrome_lock.py`, `scripts/ci_assert_engine_content.py` (where job builds real embed).

---

## Windows (`chrome/windows`)

- `WebKitHost.dll` — `WKView` / `WKPage` C API.
- WinUI parents native HWND; polls URL/title every 400 ms.
- `WEBKITIUM_LAUNCH_URL` in `OpenInitialTabAsync`.
- CI: `dotnet` on `PATH`; `WebKitSrc` / `WebKitBuild` MSBuild props.

**Gaps:** Lock not TLS-backed; navigation via polling only; WebGPU proven separately.

**Broken if:** `WebKit.dll` missing; WebView2 or `windows-min` reintroduced.

---

## Linux GTK (`chrome/linux`)

- `build.rs` fails without `WEBKIT_GTK_BUILD`.
- Per-tab `webkit6::WebView`; lock CSS from URI on commit/finish.
- `WEBKITIUM_LAUNCH_URL` for first tab.

**Gaps:** Scheme-based lock; harness tests still `#[ignore]` until bundle on PATH.

**Broken if:** distro WebKitGTK pkg-config; wrong Debug/Release GTK path.

---

## Android (`chrome/android`)

- Gradle requires `WPEVIEW_AAR`.
- `createWpeEngineView` → `WPEView`.
- `WEBKITIUM_LAUNCH_URL` on first tab + WebView create.
- CI: `ANDROID_HOME` in engine and chrome Gradle steps.

**Gaps:** Lock from chrome URL string; Device Farm may not pass launch env.

**Broken if:** `WPEVIEW_AAR` unset.

---

## macOS (`chrome/macos`)

- `PinnedEngineWebView` — `WKWebView` when `PinnedEnginePaths.inProcessEmbedAvailable`.
- `TabEngineHost` loads via `TabWebViewRegistry` or `PinnedEngineLaunch` fallback.
- Placeholder UI remains when frameworks absent (not removed).
- CI: `WEBKIT_FRAMEWORK_PATH`, `swift build -Xlinker -F`, `applyCILaunchURLIfPresent()`.

**Gaps:** Not yet `WKView` C host like Windows; lock is URL-prefix.

**Broken if:** `WebKit.framework` missing at build/runtime path.

---

## iOS (`chrome/ios`)

- Same pattern as macOS: `PinnedEngineWebView` + embed script.
- `PinnedEngineLaunch` stub when embed unavailable.
- Xcode includes `TabEngineHost`, `PinnedEngine*` sources.
- CI: embed frameworks after `xcodebuild`; patch check can use persistent `NG_IOS_WEBKIT_PATH`.

**Gaps:** Embed requires prebuilt simulator WebKit tree on runner; lock URL-prefix.

**Broken if:** frameworks not copied into `.app/Frameworks`.

---

## Blue lock — cross-cutting

| | Engine TLS? | CI fork proof needs |
|--|-------------|---------------------|
| All platforms today | **No** — `https://` on URL string | Bundle manifest + screenshot lock assert + **content** assert when embed active |

Wire engine secure-origin / TLS APIs when ports expose them.

---

## CI workflows

| Workflow | GUI + engine bundle |
|----------|---------------------|
| `windows-release` | Yes |
| `linux-gtk-build` | Yes |
| `macos-release` | Yes |
| `ios-release` | Yes |
| `android-release` | Yes |
| `browser-shell-screenshots` | Proof workflow (dispatch) |
| ~~`linux-ci.yml`~~ | **Deleted** |

---

## Engineering priorities

1. **TLS-backed lock** per port.
2. **macOS/iOS** — port-native `WKView` host (Windows `WebKitHost` pattern).
3. **Harness** — enable Linux/Windows smoke against bundled engine.
4. **Android** — pass `WEBKITIUM_LAUNCH_URL` through Device Farm or local emulator docs.

See: [`ENGINE_EMBED.md`](ENGINE_EMBED.md), [`MINIBROWSER_GAPS.md`](MINIBROWSER_GAPS.md), [`../chrome/README.md`](../chrome/README.md).

Historical pre-recovery audit: [`AGENT_AUDIT.md`](../AGENT_AUDIT.md).
