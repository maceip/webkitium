# Omnibar — interaction contract

The omnibar (unified address + search + command bar) is the primary brand-recognition surface. Each platform shell implements this spec natively; token values drive the look.

## Scope

This spec governs **behavior and layout proportions**, not rendering. Rendering is per-platform: SwiftUI on macOS/iOS, WinUI on Windows, Compose on Android, GTK4 on Linux.

## Visual anatomy

```
┌─[lockmark]─[origin chip]──────[input/suggestion]──────[actions]─┐
└─────────────────────────────────────────────────────────────────┘
```

| Region | Role | Tokens |
|---|---|---|
| Outer shape | Container | `shape.omnibar`, `material.omnibar` |
| Lockmark | Security badge | `accent.fill` + platform system lock icon |
| Origin chip | Current origin | `text.secondary`, truncation per Chrome rules |
| Input/suggestion | Editable text + inline completion | `text.primary`, `accent.fillSubtle` for inline completion highlight |
| Actions | Reload, bookmark, extensions | `text.tertiary`, `surface.hover` on hover |

## States

1. **Rest** — origin chip visible, input shows origin in `text.secondary`.
2. **Focused** — input selects all; suggestion dropdown appears with `material.contextMenu`.
3. **Typing** — origin chip hidden; input shows user text in `text.primary`; inline completion in `accent.fillSubtle`.
4. **Unsafe origin** — `text.danger` for origin; lockmark replaced with platform "not secure" glyph.
5. **Preview** (fingerprint/passkey prompt inline) — see authenticator spec; omnibar dims to `surface.sunken`.

## Interaction contract

Same across platforms:

- `Cmd/Ctrl+L` focuses and selects all.
- `Esc` restores origin chip when focus unchanged.
- `Tab` accepts inline completion if present; otherwise moves focus.
- Typing `?` prefix switches to keyword search mode.
- Typing `>` prefix switches to command palette mode (settings, extensions, tabs).
- Right-click on omnibar → context menu with Paste, Paste and Go, Edit Search Engines.
- Middle-click on a suggestion opens in new tab.

## Per-platform variations — allowed and not allowed

**Allowed to diverge** (platform idiom):
- Location: macOS/Windows/Linux top-anchored; iOS/Android bottom-floating pill.
- Material: per `platform-overrides/*.tokens.json`.
- Reload/bookmark icon set: platform-native glyph family (SF Symbols, Fluent, Material Symbols, Adwaita).
- Keyboard affordance: macOS shows `⌘L`, Windows `Ctrl+L`, mobile shows no glyph.
- Haptics on submit (iOS/Android only).

**Must NOT diverge** (brand-critical):
- Shape radius (comes from `shape.omnibar`; must be identical on a given user's theme across devices).
- Input-vs-chip behavior (origin chip, inline completion, prefix routing).
- Keyboard shortcut set and order of actions.
- Order of visual regions (lockmark always leading, actions always trailing).
- Suggestion dropdown structure: 3-column grid (icon | label | kbd) with `accent.fillSubtle` for the selected row.

## Accessibility

- Minimum 44pt/44dp touch target for all interactive regions.
- Focus ring uses `border.focus` at platform-accessibility-scale thickness (normally 2px, high-contrast 4px).
- Origin chip and lockmark announce as a single "address and security" group to screen readers.
- Dynamic Type / Text Scaling: type sizes scale; `shape.omnibar` does not (prevents the pill from looking like a button at 200% text).

## Implementation checklist (per platform)

- [ ] Consumes semantic tokens (`surface.chrome`, `accent.*`, `text.*`) — not base tokens directly.
- [ ] Re-renders on `browser.theme.onChanged`.
- [ ] Respects platform reduced-motion setting.
- [ ] Lockmark uses platform system lock icon — never ships a custom shield that web content could imitate.
- [ ] Passes the golden-image tests in `design/tests/omnibar/` (tokens-only; platform materials are snapshot separately).
