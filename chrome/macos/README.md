# macOS Chrome

Target stack: SwiftUI first, AppKit where native macOS behavior requires it, and Apple's browser sample material as fallback/reference architecture.

Compile baseline:

```sh
cd chrome/macos
swift build
```

The first macOS pass should prefer an existing maintained SwiftUI browser shell if we find one with acceptable licensing. If not, use Apple's sample structure as the reference for app target, tab view model, tab content view, engine surface, and process-separation boundary. The sample rendering engine is not the product engine; its chrome shape and process model are the useful parts.

Tabs are currently native SwiftUI `TabView` items. This is intentionally a compile baseline, not the final browser tab design.

Reference:

- https://developer.apple.com/documentation/BrowserEngineKit/developing-a-browser-app-that-uses-an-alternative-browser-engine
- https://developer.apple.com/documentation/webkit/webkit-for-swiftui
- https://github.com/nuance-dev/Web
