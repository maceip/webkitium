# Settings menus & pages — interaction contract

Long-dwell surface. Must feel like the same app on every platform, but also feel native enough that OS-level expectations (search, back gesture, sidebar) work.

## Scope

- The top-level settings entry (Menu bar → Webkitium → Settings on macOS, Hamburger → Settings on Windows/Linux, tab kebab → Settings on iOS/Android).
- `chrome://settings/*` internal pages.
- Per-site settings sheets raised from the omnibar lockmark.

## Structural model

Two-pane: **navigation** (left / top / drawer depending on platform) + **detail**.

```
┌───────────────┬─────────────────────────────────────┐
│ [Search]      │  Page title                         │
│ General       │  ──────────────────────────────      │
│ Appearance *  │  Group title                        │
│ Privacy       │  ┌──────────────────────────────┐   │
│ Sync          │  │ Row label         [control]  │   │
│ Passkeys      │  │ Description                  │   │
│ Extensions    │  └──────────────────────────────┘   │
│ About         │  ...                                │
└───────────────┴─────────────────────────────────────┘
```

`*` marker = active section, rendered with `accent.fillSubtle` background, `text.primary` label.

## Platform layout mapping

| Platform | Navigation | Detail |
|---|---|---|
| macOS | Translucent sidebar (`material.settingsSidebar`) — Liquid Glass | Inline right pane, resizable |
| Windows | NavigationView sidebar, MicaAlt | Inline right pane |
| Linux | libadwaita `AdwNavigationSplitView` | Inline right pane |
| iOS | Full-screen list, pushes to detail | Pushed detail view |
| Android | `ModalNavigationDrawer` or list with back stack | Full-screen detail |

Tablets (iPadOS, Android large) use the two-pane desktop layout.

## Tokens used

- Navigation surface: `material.settingsSidebar` (platform) / `surface.chrome` (fallback).
- Active row: `accent.fillSubtle` bg + `text.primary` label.
- Group card: `surface.chromeRaised`, `radius.md`, `border.subtle` 1px.
- Row label: `text.primary`; description: `text.secondary`.
- Control accent: `accent.fill`.
- Link: `text.link`.
- Section heading: `text.secondary` at `font.size.footnote`, tracking +0.06em, ALL CAPS (platform-conventional).

## Row patterns (brand-critical)

All settings rows follow one of five patterns. Order within a group is label-control:

1. **Toggle** — label + description on the left, native switch on the right.
2. **Select** — label on the left, native dropdown/popup on the right showing current value.
3. **Slider** — label above, native slider below, value label to the right at `font.size.footnote`.
4. **Link row** — label + description + trailing chevron; entire row is tap target.
5. **Action row** — label only; tap invokes action (no chevron). Destructive action rows use `text.danger` for label.

## Search

A search field at the top of navigation filters across all settings, matching against row labels, descriptions, and keywords. Results show the group path as a breadcrumb. This is brand-critical — keyboard shortcut `Cmd/Ctrl+F` focuses settings search from anywhere in settings.

## Per-site settings

Raised from the lockmark as a sheet (mobile) or popover (desktop). Uses `material.contextMenu`. Contains: site permissions toggles (camera, mic, location, notifications), cookies, clear site data. Does **not** contain theme controls — those live in Appearance.

## Theme editor location

Settings → Appearance → Theme. Shows:
- Brand color picker (OKLCH wheel; writes to `color.brand`).
- Appearance segmented control (Light / Dark / Auto).
- Density (Comfortable / Compact) — writes to `shape.omnibar` and `space` presets.
- "Installed themes" list (if `theme.packages` permission granted to any extension).
- "Reset to default" action row (destructive).

Changes are **live-previewed** via `browser.theme.preview()` while the user is interacting; committed to sync on blur / after a 1s idle.

## Per-platform — allowed and not allowed

**Allowed**:
- Sidebar vs drawer vs list (platform idiom).
- Native controls (iOS Toggle vs WinUI ToggleSwitch vs Adwaita Switch) — they already look different, that's fine.
- Back navigation: iOS swipe, Android predictive back, macOS/Windows in-app back button.

**Must NOT diverge**:
- Five row patterns (above).
- Group card visual structure.
- Search position and keyboard shortcut.
- Theme editor structure.
- Section ordering (General, Appearance, Privacy, Sync, Passkeys, Extensions, About) — users rely on muscle memory across devices.
