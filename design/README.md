# Webkitium Design System

Shared design language for the per-platform browser chrome.

## Scope

**Three surfaces are governed by this directory:**

| Surface | Themeable by user? | Themeable by extension? | Why |
|---|---|---|---|
| Omnibar (address bar) | Yes | Yes, with `"theme"` permission | Primary brand-recognition surface |
| Context menu (right-click) | Yes | Yes | High-visibility cross-platform interaction |
| Settings menus & pages | Yes | Yes | Long-dwell surface; must feel coherent |
| **WebAuthn authenticator** | **No** | **No** | **Security boundary. See `components/authenticator/SECURITY_BOUNDARY.md`** |
| Everything else (tab strip, toolbar, download shelf, etc.) | Platform default | No | Falls back to OS idiom |

Every other pixel of chrome uses the host platform's native look. We do **not** try to make a Mica window on Windows look like a Liquid Glass window on macOS. We make the omnibar, context menu, and settings feel like the *same app* regardless of platform.

## Non-goals

- A cross-platform widget toolkit. Platform shells own rendering.
- Pixel-identical parity. Native materials, radii, and type will diverge by design.
- A component library. This is a token + spec system; each platform implements the spec in its native framework (SwiftUI, WinUI, Compose, GTK, UIKit).

## Brand model: user-owned, not vendor-owned

The user's theme *is* the brand they see. Webkitium ships a default palette but it is the *floor*, not the ceiling. A user choosing a deep-red OLED theme on Windows expects the same palette on Android. That requires:

1. A single machine-readable token graph (W3C DTCG format, see `tokens/schema/`).
2. A writable extension API surface (`extension-api/`) that exposes the themeable subgraph.
3. Sync via the existing loopback Chromium-shaped sync server (`sync/theme-record.proto`).

The extension API is **co-designed with the token schema**: every writable token is addressable through the API, every non-writable token (secure UI) is not. There is no second surface for "theming" outside the token graph.

## Directory layout

```
design/
├── README.md                       (this file)
├── tokens/
│   ├── schema/                     W3C DTCG + webkitium extensions
│   ├── base/                       Default brand floor (color, type, motion…)
│   ├── semantic/                   Role-based (surface.primary, text.subtle)
│   ├── platform-overrides/         Native material hints per OS
│   └── secure-ui/                  FIXED tokens for authenticator
├── extension-api/                  Design extension API (co-designed with tokens)
├── sync/                           Protobuf for theme sync
├── components/                     Per-component interaction specs
└── tooling/                        Token build pipeline (later)
```

## Build pipeline (future, not in this skeleton)

Tokens are source-of-truth JSON. A small TypeScript transformer emits:

- `chrome/macos/Generated/Tokens.swift` — `Color`/`Material` extensions, `@Environment(\.theme)`
- `chrome/ios/Generated/Tokens.swift` — same, UIKit+SwiftUI
- `chrome/windows/Generated/Tokens.xaml` — WinUI `ResourceDictionary`
- `chrome/android/generated/Tokens.kt` — Compose `MaterialTheme` extension
- `chrome/linux/generated/tokens.css` — GTK4 CSS custom properties
- `browser/extensions/generated/theme-api.cc` — C++ binding for the extension API

All generators read the same `tokens/` source and honor the `protection` field.

## See also

- `components/omnibar/SPEC.md` — interaction contract for the address bar
- `components/authenticator/SECURITY_BOUNDARY.md` — why the authenticator cannot be themed
- `extension-api/README.md` — design rationale for the `browser.theme` API
