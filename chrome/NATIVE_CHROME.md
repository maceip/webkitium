# Native Chrome Groundwork

This directory is the landing zone for replacing MiniBrowser with platform-native browser chrome.

The implementation rule is: native UI first. Continuity is a product contract, not a shared UI framework. Each shell should use the platform's normal app stack and keep tab, address, security, and prompt behavior aligned with the other platforms.

## Shared Contract

The browser core eventually owns:

- tab identity, lifecycle, restoration, and session persistence
- navigation commands and normalized location/search handling
- title, favicon, loading, progress, crash, and security snapshots
- permission decisions and prompt routing
- WebAuthn/passkey requests and platform authenticator dispatch
- downloads, find-in-page, devtools, and page action command IDs

Each native chrome owns:

- native window, tab strip, toolbar, menus, and shortcuts
- native text input, focus, accessibility, drag/drop, and animations
- native permission, credential, download, file, share, and settings presentation
- platform-specific edge cases such as predictive back, titlebar integration, system colors, and multi-window behavior

The first artifact in this directory is a buildable native baseline per platform. A browser-core adapter can come later, once the native shells have real shape.

## Platform Direction

### macOS

Use SwiftUI where it fits and AppKit where mature macOS browser chrome requires it. DuckDuckGo's Apple browsers repo is the strongest practical Apple reference found so far: real iOS and macOS browsers, Apache-2.0, active releases, a shared package layout, and mature macOS tab/address/window code. Apple's BrowserEngineKit sample remains the official architecture fallback for alternative browser engine process structure.

Tabs baseline: SwiftUI `TabView` owns the native tab presentation for now. The browser command surface can later replace the placeholder tab state without changing the macOS-native presentation.

Current reference:

- DuckDuckGo Apple browsers: [duckduckgo/apple-browsers](https://github.com/duckduckgo/apple-browsers)
- Apple Developer sample: [Developing a browser app that uses an alternative browser engine](https://developer.apple.com/documentation/BrowserEngineKit/developing-a-browser-app-that-uses-an-alternative-browser-engine)
- Apple WebKit for SwiftUI: [WebKit for SwiftUI](https://developer.apple.com/documentation/webkit/webkit-for-swiftui)
- Open-source reference candidate: [nuance-dev/Web](https://github.com/nuance-dev/Web)

Initial macOS slice:

1. Compile the SwiftUI package under `chrome/macos`.
2. Study DuckDuckGo's `macOS/DuckDuckGo/MainWindow`, `NavigationBar`, `Tab`, and `TabBar` areas for native browser chrome structure.
3. Replace the placeholder `WKWebView` surface with our engine surface.
4. Bind tab, URL, loading, and security state once browser core exposes a native-friendly boundary.
5. Keep BrowserEngineKit/XPC process separation as architecture reference for future engine process work.

### Android

Use Kotlin, Jetpack Compose, Material 3, edge-to-edge layout, and predictive back. For embedded web content in Compose, Android's current guidance is still `AndroidView` around `WebView`; there is no first-party WebView composable. Third-party Compose WebView libraries are useful references but should not own browser behavior.

Tabs baseline: Navigation 3 plus Material 3 Adaptive `SupportingPaneSceneStrategy`. On phones, tabs are a destination/overview. On foldables and larger screens, tabs can remain visible beside the page as a supporting pane.

Current reference:

- Android embedded web guidance: [In-app browsing using Embedded Web](https://developer.android.com/develop/ui/views/layout/webapps/in-app-browsing-embedded-web)
- Compose adaptive release notes with predictive back support: [Compose Material 3 Adaptive](https://developer.android.com/jetpack/androidx/releases/compose-material3-adaptive)
- Open-source reference candidate: [KevinnZou/compose-webview-multiplatform](https://github.com/KevinnZou/compose-webview-multiplatform)

Initial Android slice:

1. Compile the Compose app under `chrome/android`.
2. Replace the placeholder `WebView` with our engine surface when available.
3. Wire predictive back to tab history first, then tab close, then app exit.
4. Keep browser chrome in Compose and host engine content through `AndroidView` until a dedicated engine Composable exists.
5. Reuse the Android WebAuthn provider already added in browser core for passkeys and largeBlob requests.

### Windows

Use Windows App SDK with WinUI 3, native `TabView`, native titlebar integration, and WebView2 samples as references. The strongest off-the-shelf browser sample is Microsoft's WebView2Browser, but it is Win32/C++ with web-rendered controls; use it for browser behavior and WebView2 API coverage, not as the final WinUI chrome.

Tabs baseline: WinUI `TabView` with closeable, reorderable native tab items.

Current reference:

- Horizon WinUI browser reference: [horizon-developers/browser](https://github.com/horizon-developers/browser)
- Microsoft WinUI 3 WebView2 sample: [WinUI 3 sample app](https://learn.microsoft.com/en-us/microsoft-edge/webview2/samples/webview2-winui3-sample)
- Microsoft browser sample: [WebView2Browser](https://github.com/MicrosoftEdge/WebView2Browser)
- Microsoft samples repo: [WebView2Samples](https://github.com/MicrosoftEdge/WebView2Samples)

Initial Windows slice:

1. Compile the WinUI 3 project under `chrome/windows`.
2. Use WinUI `TabView`, `CommandBar`, native menus, and system backdrop/titlebar APIs.
3. Study Horizon's WinUI browser chrome and tab model, but do not copy GPL-3.0 code unless licensing is intentionally accepted.
4. Port useful browser behavior from WebView2Browser into the native WinUI shell.
5. Keep WebView2 only as a sample/control reference unless the engine surface needs a Windows-specific bridge.
6. Bind Windows WebAuthn/passkey UI to the existing platform provider boundary.

### Linux

Linux remains a native shell target, but not the priority of this chrome pass. If it becomes product scope, start with GTK4/libadwaita for GNOME-grade behavior and keep continuity with the platform product contract.

Current reference:

- Existing browser core Linux WebAuthn provider using libfido2
- Future shell candidates: GTK4/libadwaita, WPEGTK, or Qt only if product scope requires it

## Continuity Rules

- Same command IDs everywhere; different menu placement is fine.
- Same security vocabulary everywhere; different iconography is fine.
- Same tab ordering and restoration semantics everywhere.
- Same WebAuthn/permission decision flow everywhere; native sheets/dialogs are expected.
- Same keyboard command set where the platform supports it; platform conventions win on modifier keys.
- No legacy-device compatibility layer in the chrome. Current stable platform baselines only.

## Next Build Steps

1. Get the native baselines compiling in their own toolchains.
2. Stand up macOS first, using Apple's browser sample material as the official fallback if no better maintained SwiftUI shell fits.
3. Stand up Android Compose with predictive back behavior.
4. Stand up Windows WinUI 3 with `TabView` and use WebView2Browser as the behavioral reference.
5. Add platform-native smoke tests once the placeholders are connected to browser core.
