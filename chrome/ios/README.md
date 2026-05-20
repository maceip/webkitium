# Webkitium — iOS shell

SwiftUI chrome for iPhone/iPad simulator and device. Page content uses **pinned** `WebKit.framework` embedded in `Webkitium.app` when `scripts/ios_embed_webkit_frameworks.sh` has run; otherwise a **placeholder** panel explains the missing embed (UI chrome is kept).

## Stack

- Xcode project: `Webkitium.xcodeproj`
- SwiftUI + `WKWebView` via `PinnedEngineWebView` (loaded from embedded frameworks, not system Safari WebKit)
- FFI: `WebkitiumUrl`, `WebkitiumSuggestions` packages from `browser/`

## Prerequisites

- Xcode 16+ with iOS simulator runtime
- Built iOS WebKit tree: `perl Tools/Scripts/build-webkit --debug --ios-simulator` under `NG_IOS_WEBKIT_PATH` (default `~/W/webkit-ios-src`)

## Build & run (local)

```sh
SRC="$HOME/W/webkit-ios-src"
ENGINE="$SRC/WebKitBuild/Debug"
cd chrome/ios
xcodebuild -project Webkitium.xcodeproj -scheme Webkitium \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build build
APP=$(find build -name Webkitium.app -type d | head -1)
bash ../../scripts/ios_embed_webkit_frameworks.sh "$APP" "$ENGINE"
# Install on simulator via Xcode or simctl
```

## CI

- `ios-release` — builds engine, chrome, embeds frameworks, bundles tarball
- `browser-shell-screenshots` — requires prebuilt tree on runner + embed + `WEBKITIUM_LAUNCH_URL`

## Environment

| Variable | Purpose |
|----------|---------|
| `WEBKITIUM_LAUNCH_URL` | Seed navigation (e.g. Wikipedia) in `iOSRootView` |
| `NG_IOS_WEBKIT_PATH` | Persistent WebKit checkout on self-hosted runner |

## Files

| File | Role |
|------|------|
| `PinnedEngineWebView.swift` | `UIViewRepresentable` + `TabWebViewRegistry` |
| `TabEngineHost.swift` | Per-tab navigation |
| `WebView.swift` | `WebContentArea` — embed or placeholder |
| `PinnedEngineLaunch.swift` | Log stub when embed unavailable |

## Policy

See [`docs/ENGINE_EMBED.md`](../../docs/ENGINE_EMBED.md). Do not claim system `WKWebView` / App Store WebKit as Webkitium's engine.
