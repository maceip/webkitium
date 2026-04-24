# Webkitium — macOS shell

SwiftUI + AppKit + Liquid Glass (macOS 26 Tahoe). Second reference shell,
companion to `chrome/windows/`. Consumes the same portable `browser/color/`
library through a Swift Package dependency, so palette generation and
semantic resolution are byte-identical to Windows and Android.

## Scope of the current sketch

- [x] `NSWindow` with **Liquid Glass** window backdrop (`.windowBackground`
      material on macOS 15 / `.glassEffect()` on macOS 26+)
- [x] `ExtendsContentIntoTitleBar`-equivalent: `.windowStyle(.hiddenTitleBar)`
      so the omnibar sits in the title bar band with native traffic lights
- [x] **Omnibar** component per `design/components/omnibar/SPEC.md`
- [x] Light / Dark appearance via SwiftUI's `@Environment(\.colorScheme)`
- [x] Runtime palette updates through `PaletteProvider` (observable
      `@Published` semantic colors; views rebind automatically)
- [x] Dev-only **⌘⇧T** shortcut cycles the four test seeds (blue → magenta
      → green → near-mono), same seeds as the Windows shell
- [ ] WebView2 equivalent — `WKWebView` placeholder, actual WebKit integration
      comes with the WebKit downstream work
- [ ] Tab strip — not started
- [ ] Context menu component
- [ ] Settings window
- [ ] Authenticator window
- [ ] `browser.theme` extension API wiring — `PaletteProvider.applySeed(_:)`
      is the implementation target

## File layout

```
chrome/macos/
├── README.md                          this file
├── Package.swift                      SwiftPM project manifest
└── Sources/Webkitium/
    ├── WebkitiumApp.swift             @main, App, Scene wiring
    ├── Theme/
    │   ├── PaletteProvider.swift      ObservableObject that calls the C
    │   │                              bridge, publishes SemanticPalette
    │   └── SemanticColors.swift       Color extensions + DarkModeAware
    │                                  views bound to PaletteProvider
    └── Views/
        ├── RootView.swift             Window layout: omnibar + content
        └── Omnibar.swift              Pill control
```

The portable color library lives at `../../browser/color/` and is pulled
in via SwiftPM `.package(path:)`. Its `Package.swift` declares a single
`WebkitiumColor` library target that compiles `ColorRamp.cpp`,
`OklchColor.cpp`, `SemanticPalette.cpp`, and `ColorBridgeC.cc` -- the
same files the Windows CMake build uses.

## How to build

Requires:

- **macOS 15 Sequoia or later** (15 for building, 26 Tahoe recommended at
  runtime for Liquid Glass; the shell falls back to `.ultraThinMaterial`
  on older releases)
- **Xcode 16.4+** or Swift 6.0 toolchain
- **Swift Package Manager** — no Xcode project file committed

From a fresh checkout:

```sh
cd chrome/macos
swift build
swift run webkitium
```

Or open in Xcode:

```sh
cd chrome/macos
open Package.swift
```

## Design decisions worth reading the code for

- **One color source of truth.** `PaletteProvider` calls
  `wk_palette_resolve_semantic()` from the C bridge; every visible color
  in the app is a lookup on the resulting dictionary. There is no Swift-
  side "default palette" file and no `Color(hex: "#1F5AE0")` literals in
  the shell code. If the algorithm changes in `browser/color/ColorRamp.cpp`
  the shell picks it up on rebuild.
- **Liquid Glass in a modifier, not a subclass.** `.glassEffect()` is the
  SwiftUI-native way on macOS 26. No `NSVisualEffectView` backing for
  ordinary surfaces. The authenticator window (future) will still use a
  fixed-style `NSVisualEffectView` so its material is not theme-driven --
  same philosophy as `design/components/authenticator/SECURITY_BOUNDARY.md`.
- **Hidden title bar, omnibar in its place.** `.windowStyle(.hiddenTitleBar)`
  collapses the system title bar; the omnibar band pads for the traffic
  lights at the leading edge (`kTrafficLightReserveWidth` in RootView.swift)
  and mirrors the SetTitleBar() pattern on Windows.
- **No NSColor.controlAccentColor following.** Once a user has a webkitium
  theme, we stop mirroring the system accent; before that, we still show
  our algorithmic default, not the OS accent. Consistent across platforms.
- **SwiftUI `@Published` for palette updates** — same idea as the Windows
  PaletteProvider mutating `SolidColorBrush.Color`. Swift's reactivity
  handles rebinding without our intervention; the only manual work is
  re-running `wk_palette_resolve_semantic` twice (once per appearance)
  when the seed changes.

## Cross-platform contract test

For any given seed, the shell computes `SemanticPalette` identically to
Windows and Android. A manual test: set the seed on all three shells to
`0xFFD21F6B` (the magenta test seed); `SurfaceChrome` must resolve to the
same ARGB on all three. The C bridge guarantees this by construction.
