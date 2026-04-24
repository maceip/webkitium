# `browser.theme` Extension API

The design extension API is the **writable surface** of the token graph. It is co-designed with `tokens/schema/tokens.schema.json`: every `themeable` token is addressable through this API; every `platform-only` or `secure-fixed` token is not.

Chrome's `chrome.theme` is not sufficient — it only exposes a handful of frame colors. We need a graph-shaped read/write API plus sync.

## Shape at a glance

```ts
const theme = await browser.theme.get();
theme.tokens.color.brand = "oklch(0.55 0.22 340)";     // deep magenta
theme.tokens.shape.omnibar = "20px";
await browser.theme.set(theme);                         // syncs by default
```

## Addressing

Token paths use dots, matching the token graph. A path like `color.brand` resolves to `base/color.tokens.json` → `brand.9` (because the schema's `api-path` extension redirects it). A path like `accent.fill` resolves to the active semantic layer (`semantic/light.tokens.json` or `dark.tokens.json`) — extensions cannot target one appearance; writes apply to both and the pipeline recomputes dark-variant shades.

Paths into `tokens/platform-overrides/**` are **readable but not writable** via extensions (protection: `platform-only`). This keeps Liquid Glass / Mica / Material You tuning under vendor control.

Paths into `tokens/secure-ui/**` are **neither readable nor writable**. The API pretends they do not exist: `get()` does not include them, `set()` on their paths rejects with `ERR_PROTECTED_PATH`.

## Permissions

Three permissions in `manifest.json`, graded by blast radius. See `manifest-permissions.md` for the full table.

| Permission | Read themeable | Write themeable | Install named theme packages |
|---|---|---|---|
| (none) | No | No | No |
| `"theme.read"` | Yes | No | No |
| `"theme"` | Yes | Yes (active theme) | No |
| `"theme.packages"` | Yes | Yes | Yes (managed list) |

## Sync

A themed write produces a `ThemeSpecifics` record that rides on the existing sync pipeline (`browser/sync/`). Defined by `sync/theme-record.proto`. Last-writer-wins at the token level (not document level) so a Windows device's brand color change doesn't clobber the Android device's `shape.omnibar` override made 200ms earlier.

Users can see the active theme at `chrome://settings/theme` on any device; it matches bit-for-bit across devices within one sync round trip.

## Why the authenticator is invisible to this API

`secure-ui/**` paths are not in `get()`'s result object. From the extension's perspective, the tokens don't exist. This is deliberate:

- **No feature detection**: an extension cannot discover that a secure-fixed brand color exists, so it cannot build UI that mimics it.
- **No read side-channel**: even the *values* are not observable, which prevents an extension from pixel-matching the authenticator's accent in an overlay.

The authenticator also renders outside any renderer process — see `components/authenticator/SECURITY_BOUNDARY.md`.

## Surfaces covered

The API governs exactly three user-facing surfaces:

1. **Omnibar** (`components/omnibar/SPEC.md`)
2. **Context menu** (`components/context-menu/SPEC.md`)
3. **Settings menus & pages** (`components/settings/SPEC.md`)

Writes to tokens that only affect other chrome (tab strip, toolbar, download shelf) are accepted but only surface visually where the three above read them. The rest of the chrome follows platform defaults — deliberate, see top-level `README.md`.

## Versioning

`browser.theme.apiVersion` returns the schema version. Extensions should check before writing. Unknown paths in `set()` are **rejected atomically** (not silently ignored) so a theme authored against v1.1 cannot partially apply on v1.0 runtimes.

## Live preview

`browser.theme.preview(partial)` applies a token set *without persisting or syncing*, returning a `PreviewHandle`. `handle.commit()` persists, `handle.revert()` rolls back. Used by theme-editor extensions to avoid sync storm while the user is dragging a color slider.

## Relationship to Cloudscape

Cloudscape's token model (role-based, theme-able, graph-shaped) is a good structural reference; we lift the *pattern* (semantic tokens → base tokens → generated platform artifacts) but not the code, since it is React-only and ours is cross-native. Where possible, semantic token names match Cloudscape's (`surface`, `text.primary`, `border.default`) so front-end devs onboard faster.
