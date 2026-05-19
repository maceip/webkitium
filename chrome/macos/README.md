# macOS chrome

SwiftUI shell. In-process **`WKWebView`** loads from pinned `WebKit.framework` when `WEBKIT_FRAMEWORK_PATH` / `DYLD_FRAMEWORK_PATH` point at your WebKit build; otherwise falls back to external **MiniBrowser** (`WEBKIT_MINIBROWSER`).

```bash
export WEBKIT_MINIBROWSER="$HOME/webkit-src/WebKitBuild/Debug/MiniBrowser.app/Contents/MacOS/MiniBrowser"
cd chrome/macos && swift build -c debug
```
