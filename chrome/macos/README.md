# macOS Chrome

Target stack: SwiftUI where it fits, AppKit where mature macOS browser chrome requires it, DuckDuckGo's Apple browsers as the primary practical reference, and Apple's browser sample material as official fallback/reference architecture.

Compile baseline:

```sh
cd chrome/macos
swift build
```

DuckDuckGo's Apple browsers repo is the strongest Apple-platform browser reference found so far. It is Apache-2.0, actively released, and includes real macOS/iOS browser app structure plus shared Swift packages. The most relevant macOS areas are `macOS/DuckDuckGo/MainWindow`, `NavigationBar`, `Tab`, `TabBar`, state restoration, and the `SharedPackages/BrowserServicesKit` browser services layer.

Apple's BrowserEngineKit sample remains useful for official alternative browser engine process architecture. The sample rendering engine is not the product engine; its process model is the useful part.

Tabs are currently native SwiftUI `TabView` items. This is intentionally a compile baseline, not the final browser tab design.

Reference:

- https://github.com/duckduckgo/apple-browsers
- https://developer.apple.com/documentation/BrowserEngineKit/developing-a-browser-app-that-uses-an-alternative-browser-engine
- https://developer.apple.com/documentation/webkit/webkit-for-swiftui
- https://github.com/nuance-dev/Web
