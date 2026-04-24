# Context menu — interaction contract

The right-click (and long-press, and keyboard menu key) menu. High-visibility cross-platform surface; small enough to unify cleanly.

## Scope

Menus raised by the browser process from chrome surfaces (page, link, image, text selection, tab, back/forward, omnibar). **Web-content-initiated menus** (`contextmenu` event) are out of scope here — those get the platform default unless an extension customizes via `contextMenus` API.

## Anatomy

```
┌─────────────────────────────┐
│ ✳ Action label      ⌘K     │   leading icon | label | trailing accelerator
│ ✳ Action label              │
│ ─────────────────────────── │   divider (semantic, not cosmetic)
│ Section heading             │   optional, platform-styled
│ ✳ Action label        ›     │   trailing chevron = submenu
│ ─────────────────────────── │
│ Destructive action          │   text.danger for label
└─────────────────────────────┘
```

## Tokens used

- Surface: `material.contextMenu` (platform override) layered over `surface.overlay`.
- Row rest: transparent. Hover: `surface.hover`. Pressed: `surface.pressed`. Selected/keyboard-focused: `accent.fillSubtle`.
- Label: `text.primary`. Destructive: `text.danger`. Disabled: `text.tertiary`.
- Accelerator: `text.tertiary`, mono font at `font.size.footnote`.
- Divider: `border.subtle`, 1px.
- Shape: `shape.contextMenu` (fallback `radius.md`).

## Structure rules (brand-critical)

1. **Icons are optional but when present occupy a fixed 20dp leading gutter.** Menus without icons set that gutter empty — labels never reflow.
2. **Accelerators right-align** and use the platform accelerator format (`⌘K` macOS, `Ctrl+K` Windows/Linux, hidden on mobile).
3. **Destructive actions are last in their group** and use `text.danger` for the label only (not the icon).
4. **Submenu chevron** is platform-native glyph, sized to match label cap-height.
5. **Dividers are semantic** — one per logical group, not used for spacing. Spacing uses `space.1` gap between items.
6. **Max width** is 320dp; labels truncate with ellipsis; hover shows full via platform tooltip.

## Per-platform variations

**Allowed** (platform idiom):
- Blur/material (`material.contextMenu`): Liquid Glass on Apple, Acrylic on Windows, solid surface on Android/Linux.
- Animation: iOS slides up from touch point; macOS fades+scales; Windows slides down 4dp; Android fades.
- Chevron glyph: SF Symbols `chevron.right`, Fluent ``, Material `arrow_right`, Adwaita `pan-end-symbolic`.
- Long-press on mobile raises menu with haptic `lightImpact` (from haptic token).

**Must NOT diverge**:
- Row height scaling with Dynamic Type (min 32dp, max 48dp).
- Icon-label-accelerator layout order.
- Position of destructive items.
- Color mapping (never use `accent.fill` as a background for a row; only `accent.fillSubtle` for selection).

## Keyboard

- `Up` / `Down` move focus; `Right` opens submenu; `Left` closes submenu or moves to parent.
- `Enter` / `Space` activate.
- `Esc` dismisses.
- Type-ahead: letter jumps to next item starting with that letter (case-insensitive).
- All rows must have a tab-reachable focus state using `accent.fillSubtle` + `border.focus` ring.

## Extension contribution

Extensions using `chrome.contextMenus` get rendered with the same visual rules. Their icons pass through the standard leading gutter; their labels truncate at the shared max width. No extension can override the visual rules — they provide content, not presentation.
