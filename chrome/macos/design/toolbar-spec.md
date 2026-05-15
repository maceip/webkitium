# Toolbar + Sidebar Header — locked spec

**Reference image:** [toolbar-spec.png](toolbar-spec.png) (annotated reference from product).

**Why this file exists:** earlier iterations kept drifting the toolbar
shape when adjacent features were wired (e.g. an "Add to Dock" inline
entry point got added to the right pill). This document is the **single
source of truth** for what icons live where. Any change to the toolbar
or sidebar-header icon set requires updating this file and the
reference image **first**, then matching code.

---

## Window toolbar — top of the window

| Position | Icons | Notes |
|---|---|---|
| LEFT  | `chevron.left` , `chevron.right` | One Liquid Glass pill. **NO internal divider line** — the pill itself is the border. |
| CENTER | URL field | When focused, cursor leading-aligned, NOT centered. Placeholder text can stay centered when the field is empty. |
| RIGHT | `square.and.arrow.up` , `plus` , `square.on.square` | Share / new tab / show tab overview. **3 icons, in this order.** Share greys out when there's no active page. |

**Not in the toolbar (open questions):**
- Extensions / puzzle piece — reachable via menu only for now
- Downloads — reachable via menu only for now
- Add to Dock — reachable via menu only

---

## Sidebar header — top of the left column

The leading edge of the sidebar shows two icons in a row, above any
sidebar content:

| Icon | Action | State today |
|---|---|---|
| `sidebar.left` (or `rectangle.lefthalf.inset.filled`) | Hide sidebar | Wired |
| `square.stack.3d.up` (or new-tab-group glyph) | New Tab Group | **Disabled** — we haven't built Tab Groups yet |

The sidebar must show a **visible right edge** (1px hairline) so the
divider with the detail column is clearly present, matching the top
edge that's already visible.

**Default sidebar width:** the previous `ideal: 220` was too narrow.
Bumped to `min: 200, ideal: 260, max: 420` so tab titles aren't
truncated at default.

---

## How to change this spec

1. Update [toolbar-spec.png](toolbar-spec.png) with a fresh annotated
   reference.
2. Update the tables in this file to match.
3. Update `Toolbar.swift` and `SidebarView.swift` header comments to
   match the new spec.
4. PR title should start with `chore(chrome/macos): update toolbar spec`.
