# Webkitium — Android shell

Jetpack Compose + JNI into the portable `browser/color/` C++ library.
Third reference shell, companion to `chrome/windows/` and `chrome/macos/`.
Same algorithm, same output, no Material You.

## Scope of the current sketch

- [x] Edge-to-edge `Activity` with **predictive back** (Android 14+ default)
- [x] Compose `MaterialTheme` wrapper -- consumes OUR `ColorScheme`
      derived from `browser/color/`, not `dynamicLightColorScheme()`
- [x] **Omnibar** composable per `design/components/omnibar/SPEC.md`,
      floating pill at the bottom (platform idiom)
- [x] Light / Dark via `isSystemInDarkTheme()`, same semantic resolver
      as Windows and macOS
- [x] `PaletteProvider` `ViewModel` holds a `StateFlow<SemanticPalette>`;
      Compose re-reads and rebinds on seed change
- [x] Dev-only **three-finger tap anywhere** cycles the four test seeds
      (blue → magenta → green → near-mono)
- [x] JNI bridge to `browser/color/ColorBridgeC.h` -- the same C ABI the
      macOS shell imports via Swift
- [ ] WebView placeholder (will connect to the Android WPE / WebKit GTK
      Android port eventually)
- [ ] Tab strip, context menu, settings, authenticator
- [ ] `browser.theme` extension API wiring

## File layout

```
chrome/android/
├── README.md                       this file
├── settings.gradle.kts             project-level Gradle settings
├── build.gradle.kts                project-level plugins
├── gradle.properties
└── app/
    ├── build.gradle.kts            module build (compose, JNI)
    └── src/main/
        ├── AndroidManifest.xml
        ├── cpp/
        │   ├── CMakeLists.txt      builds browser/color + JNI wrapper
        │   └── webkitium_color_jni.cc
        ├── java/dev/webkitium/
        │   ├── MainActivity.kt     entry; edge-to-edge + Compose host
        │   ├── theme/
        │   │   ├── ColorBridge.kt   JNI declarations + IntArray → Color
        │   │   ├── PaletteProvider.kt  ViewModel + StateFlow
        │   │   └── WebkitiumTheme.kt   MaterialTheme wrapper
        │   └── ui/
        │       └── Omnibar.kt       pill composable
        └── res/values/              minimal (app name, themes)
```

The portable color library lives at `../../browser/color/`. The CMake
build in `app/src/main/cpp/CMakeLists.txt` references those sources by
relative path -- same files the Windows CMake build and macOS SwiftPM
build compile.

## How to build

Requires:

- **Android Studio Koala (2024.2) or later**, or command-line:
- **Android SDK 35** (Android 15 preview/stable)
- **NDK r26+** (bundled with Android Studio)
- **Java 17+** (bundled with recent Android Studio)

From a fresh checkout:

```sh
cd chrome/android
./gradlew assembleDebug
# APK lands at app/build/outputs/apk/debug/app-debug.apk
```

Or open in Android Studio: `File → Open → chrome/android`.

A `gradlew` wrapper is not committed -- use whichever Gradle version your
Android Studio ships (`gradle wrapper --gradle-version 8.10` to generate
one, or let AS do it on first open).

## Design decisions worth reading the code for

- **Our ColorScheme, not Material You's.** `WebkitiumTheme` calls
  `MaterialTheme(colorScheme = ourScheme, ...)` but the scheme is built
  from the JNI-resolved semantic palette -- not from
  `dynamicLightColorScheme(context)`. We never call
  `DynamicColors.applyToActivitiesIfAvailable`. Users who set a brand
  color on their Windows device see the same palette on their Android
  device, independent of wallpaper.
- **Compose material overlaps.** Our semantic tokens (e.g.
  `SurfaceChrome`) are mapped onto Material 3's color roles (`surface`,
  `surfaceVariant`, `primary`, etc.) in `WebkitiumTheme.kt` so standard
  Compose components still look right. When a standard `Surface` picks up
  our `surface` color, it picks up our OKLCH-derived value.
- **One C++ library, three languages.** JNI in the Kotlin layer calls the
  exact same `wk_palette_resolve_semantic()` function that the macOS
  Swift layer calls and that the Windows C++ code calls. Cross-platform
  sRGB invariant is enforced by construction: same seed → same 22 ARGB
  outputs → same pixel on-screen.
- **Edge-to-edge by default.** `enableEdgeToEdge()` + predictive back +
  floating omnibar at the bottom. No Material You decorations.
- **No Compose Preview wallpaper tricks.** `DynamicColors` is deliberately
  absent; if a reviewer enables it on the device, our theme still wins
  because `MaterialTheme` is passed our fixed `ColorScheme`.

## Cross-platform contract test

Same manual test as `chrome/macos/README.md`: set seed `0xFFD21F6B`
(magenta) on Windows / macOS / Android; inspect `SurfaceChrome`; all
three produce the same ARGB. If any diverge, the bug is in one of the
language bridges, not in the algorithm.
