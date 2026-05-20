# Webkitium — Android shell

Kotlin + Jetpack Compose + Material 3 around **pinned WPE WebKit** (`WPEView` from the engine build), not `android.webkit.WebView` (Chromium).

JNI binds `../../browser/url/` for URL normalization and tracking-param scrubbing.

## Stack

- Kotlin 2.0.21, AGP 8.7.3, Gradle 8.11.1
- Compose BOM 2024.12.01 / Material 3 1.3.1
- compileSdk 35, minSdk 26, targetSdk 35
- NDK 27.0.12077973, CMake 3.22.1, JDK 17

## Prerequisites

- Android SDK 35, NDK 27+, JDK 17
- **Engine:** wpe-android checkout with `:wpeview:assembleDebug` producing `wpeview-*-debug.aar`

## Build & run

```sh
# 1) Build engine AAR (on wpe-android tree)
export WPEVIEW_AAR=/path/to/wpeview-debug.aar

# 2) Chrome APK
cd chrome/android
./gradlew :app:assembleDebug

./gradlew installDebug
adb shell am start -n org.webkitium.android/.MainActivity
```

CI sets `WPEVIEW_AAR` automatically after engine Gradle (`android-release`, `browser-shell-screenshots`).

## Engine embed

- `createWpeEngineView()` in `ui/WpeEngineView.kt` — `org.wpewebkit.wpeview.WPEView`
- Gradle **fails** if `WPEVIEW_AAR` is unset (no Chromium fallback)
- `WEBKITIUM_LAUNCH_URL` seeds the first tab and initial `loadUrl` in compact/expanded layouts

## What this shell includes

- Edge-to-edge Material 3 chrome (compact + expanded layouts)
- Bottom/top URL bars with **SecureLockIndicator** (HTTPS prefix on URL string)
- Tabs, find-in-page (DOM `window.find`), bookmarks/autocomplete stubs per `features.yaml`

## Roadmap

See [`features.yaml`](../../features.yaml) and [`harness_android/`](../../harness_android/).

## Non-goals / gaps

See [`docs/MINIBROWSER_GAPS.md`](../../docs/MINIBROWSER_GAPS.md). Profile persistence, extensions activation, and Device Farm launch-env for `WEBKITIUM_LAUNCH_URL` remain open.
