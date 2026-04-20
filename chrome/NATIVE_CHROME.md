# Native Chrome Groundwork

This directory is the landing zone for replacing MiniBrowser with platform-native browser chrome.

The implementation rule is: native UI, shared browser behavior. Each shell can follow the platform's current best practices, but it must bind to the same core tab model, command model, security model, and prompt model so the product feels continuous.

## Shared Contract

The browser core owns:

- tab identity, lifecycle, restoration, and session persistence
- navigation commands and normalized location/search handling
- title, favicon, loading, progress, crash, and security snapshots
- permission decisions and prompt routing
- WebAuthn/passkey requests and platform authenticator dispatch
- downloads, find-in-page, devtools, and page action command IDs

The platform chrome owns:

- native window, tab strip, toolbar, menus, and shortcuts
- native text input, focus, accessibility, drag/drop, and animations
- native permission, credential, download, file, share, and settings presentation
- platform-specific edge cases such as predictive back, titlebar integration, system colors, and multi-window behavior

The first cross-platform artifact should be a small chrome adapter boundary, not a UI framework abstraction. A native shell should receive immutable snapshots and issue command IDs back to browser core.

## Platform Direction

### macOS

Use SwiftUI as the primary UI layer with AppKit escape hatches where macOS behavior requires it. Apple's BrowserEngineKit sample is the baseline architecture fallback because it demonstrates a browser app shape with SwiftUI UI, tabs, and process-separated browser-engine plumbing. It is not automatically the macOS product shell; use it directly only if the downloaded sample's license and platform targets fit this repository.

Current reference:

- Apple Developer sample: [Developing a browser app that uses an alternative browser engine](https://developer.apple.com/documentation/BrowserEngineKit/developing-a-browser-app-that-uses-an-alternative-browser-engine)
- Apple WebKit for SwiftUI: [WebKit for SwiftUI](https://developer.apple.com/documentation/webkit/webkit-for-swiftui)
- Open-source reference candidate: [nuance-dev/Web](https://github.com/nuance-dev/Web)

Initial macOS slice:

1. Create an Xcode workspace under `chrome/macos`.
2. Import or mirror only the chrome-layer structure from Apple's sample after license and platform review.
3. Replace the sample content view with our engine surface.
4. Bind tab, URL, loading, and security snapshots from browser core.
5. Keep BrowserEngineKit/XPC process separation as the architecture reference for future engine process work.

### Android

Use Kotlin, Jetpack Compose, Material 3, edge-to-edge layout, and predictive back. For embedded web content in Compose, Android's current guidance is still `AndroidView` around `WebView`; there is no first-party WebView composable. Third-party Compose WebView libraries are useful references but should not own browser behavior.

Current reference:

- Android embedded web guidance: [In-app browsing using Embedded Web](https://developer.android.com/develop/ui/views/layout/webapps/in-app-browsing-embedded-web)
- Compose adaptive release notes with predictive back support: [Compose Material 3 Adaptive](https://developer.android.com/jetpack/androidx/releases/compose-material3-adaptive)
- Open-source reference candidate: [KevinnZou/compose-webview-multiplatform](https://github.com/KevinnZou/compose-webview-multiplatform)

Initial Android slice:

1. Create a Compose app under `chrome/android`.
2. Build tab strip, address field, page state, and overflow actions in Material 3.
3. Wire predictive back to tab history first, then tab close, then app exit.
4. Host the engine view through `AndroidView` until a dedicated engine Composable exists.
5. Reuse the Android WebAuthn provider already added in browser core for passkeys and largeBlob requests.

### Windows

Use Windows App SDK with WinUI 3, native `TabView`, native titlebar integration, and WebView2 samples as references. The strongest off-the-shelf browser sample is Microsoft's WebView2Browser, but it is Win32/C++ with web-rendered controls; use it for browser behavior and WebView2 API coverage, not as the final WinUI chrome.

Current reference:

- Microsoft WinUI 3 WebView2 sample: [WinUI 3 sample app](https://learn.microsoft.com/en-us/microsoft-edge/webview2/samples/webview2-winui3-sample)
- Microsoft browser sample: [WebView2Browser](https://github.com/MicrosoftEdge/WebView2Browser)
- Microsoft samples repo: [WebView2Samples](https://github.com/MicrosoftEdge/WebView2Samples)

Initial Windows slice:

1. Create a Windows App SDK project under `chrome/windows`.
2. Use WinUI `TabView`, `CommandBar`, native menus, and system backdrop/titlebar APIs.
3. Port useful browser behavior from WebView2Browser into the shared adapter model.
4. Keep WebView2 only as the host/control reference unless the engine surface needs a Windows-specific bridge.
5. Bind Windows WebAuthn/passkey UI to the existing platform provider boundary.

### Linux

Linux remains a native shell target, but not the priority of this chrome pass. If it becomes product scope, start with GTK4/libadwaita for GNOME-grade behavior and keep the same core adapter contract.

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

1. Add the shared chrome adapter header/API in browser core.
2. Stand up macOS first, using Apple's browser sample material as the official fallback if no better maintained SwiftUI shell fits.
3. Stand up Android Compose with the same adapter contract and predictive back behavior.
4. Stand up Windows WinUI 3 with `TabView` and use WebView2Browser as the behavioral reference.
5. Add smoke tests for the shared adapter model before investing in visual chrome tests.
