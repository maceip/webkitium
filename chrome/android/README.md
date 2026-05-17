# Webkitium — Android shell

Kotlin + Jetpack Compose + Material 3 + Android WebView. JNI binds the portable C ABI at `../../browser/url/` to power URL normalization and tracking-param scrubbing.

## Stack

- Kotlin 2.0.21
- Android Gradle Plugin 8.7.3
- Gradle 8.11.1
- Compose BOM 2024.12.01 / Material 3 1.3.1
- compileSdk 35 (Android 15), minSdk 26 (Android 8.0), targetSdk 35
- NDK 27.0.12077973, CMake 3.22.1
- JDK 17 source compatibility

## Prerequisites

- Android Studio Ladybug (2024.2.1) or later, **or** the command-line tools
- Android SDK 35
- NDK 27.0+ (install via `sdkmanager "ndk;27.0.12077973"`)
- JDK 17+ (recent Android Studios bundle one; `brew install --cask temurin@17` works too)

On a fresh macOS dev box:

```sh
brew install --cask android-studio
# Then in Android Studio: SDK Manager → install SDK 35, NDK 27, CMake 3.22
```

## Build & run

```sh
cd chrome/android
./gradlew assembleDebug
# APK lands at app/build/outputs/apk/debug/app-debug.apk

# Install + launch:
./gradlew installDebug && \
  adb shell am start -n org.webkitium.android/.MainActivity
```

## What this gives you

- One Activity, edge-to-edge, Material 3 theme with Android-12+ dynamic color
- Compose `Scaffold`: bottomBar = `BottomUrlBar` (back / TextField / ⋯ ), content = `AndroidView { WebView }`
- URL submit round-trips through `UrlBridge.normalize(input, "duckduckgo")` — the proof-of-life FFI call against `wk_url_normalize`

## What you do next

Your roadmap is [`features.yaml`](../../features.yaml) at the repo root. Pick a row, implement, add a smoke test in [`harness_android/`](../../harness_android/). CI will go red if a `required: true` feature lacks a passing test on Android once the harness is wired up.

## Explicit non-goals for this starter kit

Tab strip, multiple tabs, settings, bookmarks, history, downloads, extensions, profile switcher. URL bar + WebView only. Anywhere a feature would later go, there's a one-line `TODO: features.yaml#<id>` comment pointing at the manifest row.
