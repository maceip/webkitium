# Manifest permissions for `browser.theme`

An extension declares intent in `manifest.json`, and the browser gates the API surface based on it. Three permission levels, ordered by blast radius.

## `"theme.read"`

Grants: `browser.theme.get()`, `browser.theme.onChanged`, `browser.theme.getWritablePaths()`, read of `apiVersion`, `schemaVersion`, `platformId`.

Use case: an extension that adapts its own UI to the user's theme (e.g., a content-script button that matches the omnibar accent).

Prompt: "Read the colors and style you've chosen for the browser." — no warning icon, treated as low-risk.

## `"theme"`

Grants everything in `theme.read`, plus `set()`, `reset()`, `preview()`, `preview().commit()`, `preview().revert()`.

Use case: a theme editor extension that lets the user drag sliders and commit changes.

Prompt: "Change the colors and style of the browser." — warning icon, shown on install, re-asked on first invocation after install, honored by enterprise policy (`ExtensionThemeWriteBlocked`).

## `"theme.packages"`

Grants everything in `theme`, plus `listPackages()`, `installPackage()`, `activatePackage()`.

Use case: a theme marketplace extension that ships curated packs.

Prompt: "Install and switch between theme packs." — warning icon, enterprise-gated, logged to the extension audit log.

## Implicit permissions (not declarable)

- Writing to `tokens/platform-overrides/**` paths → **always rejected**, even with `"theme"`. Reason: these encode Liquid Glass / Mica / Material You tuning; mis-set values break a platform's material rendering in unobvious ways.
- Writing to `tokens/secure-ui/**` paths → **always rejected** and the path is elided from `get()` results. See `components/authenticator/SECURITY_BOUNDARY.md`.
- Writing to `space.*` or `elevation.*` → rejected (protection: `platform-only`). Users may pick a density preset via Settings but extensions cannot.

## Error codes

| Code | When |
|---|---|
| `ERR_PROTECTED_PATH` | Write targeted a `platform-only` or `secure-fixed` token |
| `ERR_UNKNOWN_PATH` | Path does not exist in the active schema |
| `ERR_SCHEMA_VERSION_MISMATCH` | Theme's `schemaVersion` is newer than the runtime's; write refused |
| `ERR_VALUE_TYPE_MISMATCH` | `$type` of written value doesn't match schema |
| `ERR_CONTRAST_VIOLATION` | Enforced text-on-surface contrast below AA (4.5:1 body, 3:1 large). User can override via Settings; extension cannot. |
| `ERR_RATE_LIMITED` | More than 10 `set()` calls in 1s without `preview()` |

## Contrast enforcement

The runtime validates every `set()` against WCAG AA contrast on the main text-on-surface pairs. An extension that tries to write `surface.chrome = #000` and `text.primary = #111` receives `ERR_CONTRAST_VIOLATION`. This is non-overridable by extensions; users who want eccentric palettes can override via an accessibility opt-out in the settings app only.

## Example manifest

```json
{
  "manifest_version": 3,
  "name": "Neon Theme Editor",
  "version": "1.0.0",
  "permissions": ["theme"],
  "host_permissions": [],
  "action": { "default_popup": "editor.html" }
}
```
