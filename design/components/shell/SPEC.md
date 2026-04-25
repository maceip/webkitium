# Shell — cross-platform window chrome

The browser shell has two canonical regions on every platform: **top controls** and **sidepanel**. Both are present on macOS and Windows; Android and Linux follow.

## Visual anatomy

```
┌────────────────────────── top controls ───────────────────────────┐
│  [traffic-lights / win-caption]  [omnibar]   [tabs]   [actions]   │
├──────────────┬────────────────────────────────────────────────────┤
│              │                                                    │
│  sidepanel   │   content (web view / settings / extension UI)     │
│              │                                                    │
│  - history   │                                                    │
│  - bookmarks │                                                    │
│  - extensions│                                                    │
│              │                                                    │
└──────────────┴────────────────────────────────────────────────────┘
```

| Region | Role | Tokens |
|---|---|---|
| Top controls | Container for caption controls + omnibar + tabs + global actions | `material.top-controls`, `shape.top-controls`, platform caption metrics |
| Sidepanel | Left rail for navigation between primary surfaces (history, bookmarks, paired devices, extensions, settings) | `material.sidepanel`, `shape.sidepanel`, `surface.sidepanel` |
| Content | Web view or paired-surface body | `surface.content` |

## Per-platform implementations

| Platform | Top controls | Sidepanel | Reference |
|---|---|---|---|
| macOS | `NSToolbar` + traffic-lights | `NSSplitViewController` left pane with translucent material | Apple Pages / Preview chrome |
| Windows | WinUI 3 `TitleBar` (caption controls) + custom action row | WinUI 3 `NavigationView` in left pane mode | WinUI 3 Controls Gallery |
| Android | Compose `TopAppBar` | Compose `ModalNavigationDrawer` (collapsed → bottom sheet on phones) | Material 3 |
| Linux (GTK) | `Adw.HeaderBar` | `Adw.NavigationSplitView` | libadwaita reference |

## Interaction contract

Same across platforms:

- Sidepanel collapses to icon-only at narrow widths (`< 720` px wide) and fully hides on tablet/phone breakpoints.
- Top controls height is platform-native (matches the reference app on each OS); only the omnibar inside scales.
- `Cmd/Ctrl+\` toggles sidepanel visibility.
- `Cmd/Ctrl+T` opens a new tab in the top-controls tab strip.
- Sidepanel sections register via the same content-router as Settings.

## Notes for native ports

- macOS shell uses translucent material on the sidepanel that picks up the wallpaper/photo behind the window — see Apple's Pages chrome for the reference.
- Windows shell uses Mica or Acrylic per OS version; the sidepanel inherits the window material rather than drawing its own.
- Top controls must remain valid as the window's drag region except over interactive children (omnibar, tabs, actions).
