# macOS chrome

SwiftUI shell. Page load goes to pinned **MiniBrowser** (`WEBKIT_MINIBROWSER` or `engine/MiniBrowser.app` in the platform bundle). No `WKWebView` in this target.

```bash
export WEBKIT_MINIBROWSER="$HOME/webkit-src/WebKitBuild/Debug/MiniBrowser.app/Contents/MacOS/MiniBrowser"
cd chrome/macos && swift build -c debug
```
