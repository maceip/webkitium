# Authenticator UI — Security Boundary

**The WebAuthn authenticator window (and, by extension, the password manager it grows into) is not themeable.** Not by the user, not by extensions, not by sync. This document explains why, what enforces it, and how the design system respects the line.

## Threat model

The authenticator is the browser's **trusted path**: when it says "Sign in to example.com with your passkey," the user must be able to rely on that claim. The adversary categories:

1. **Malicious web content** trying to render a fake authenticator prompt in the page, hoping the user consents with their biometric to a credential theft.
2. **Malicious extensions** with broad permissions trying to restyle the real prompt, or overlay a fake one that looks identical enough to harvest credentials or approvals.
3. **A compromised user theme synced across devices** — an attacker who gains temporary write access on one device pushes a theme that makes the authenticator blend into phishing-rendered content.

All three are mitigated by making the authenticator's visual identity **fixed, out-of-process, and distinct from any themeable surface**.

## Enforcement — four layers

### 1. Token graph — compile-time

`tokens/secure-ui/authenticator.tokens.json` carries `dev.webkitium.protection: "secure-fixed"` and `dev.webkitium.syncable: false`. The token build pipeline emits these values as **constant literals** into each platform binary (not as resources that can be swapped). A build-time assertion fails if any secure-fixed token references a themeable token.

### 2. Extension API — runtime

`browser.theme.get()` returns a `Theme` object whose `tokens` tree contains only themeable paths. Secure-fixed paths are not present — an extension using `Object.keys(theme.tokens)` cannot discover that `secure.authenticator.brand.accent` exists.

`browser.theme.set({..., "secure.*": ...})` rejects with `ERR_PROTECTED_PATH`. Paths starting with `secure.` are reserved and always rejected even if they point to no defined token.

`browser.theme.getWritablePaths()` never includes any path under `secure.`.

### 3. Sync — wire level

`sync/theme-record.proto` has no field for secure-ui tokens. A tampered client writing a record with `tokens["secure.authenticator.brand.accent"] = "..."` produces a payload the server and receivers will pass through (maps are opaque), but on the receiving client:

- The token loader rejects any path prefixed `secure.` before applying.
- The loader logs the attempt as a telemetry event `sync.theme.rejected_secure_path` with the originating client id. Repeat offenders get quarantined.

### 4. Rendering — process isolation

The authenticator window is drawn by the **browser process**, not by a renderer. It cannot be iframed (no renderer has a handle to it), cannot be overlaid (the OS ensures it lives above any web-content window as an OS-level sheet or modal), and cannot be screenshotted by web APIs (`captureWindow` returns blank on it, as with DRM content).

Platform mechanics:

- **macOS / iOS** — `NSAlert`/`UIAlertController` variant with a webkitium-managed content view. The window has `.fullSizeContentView` disabled; no web view embedded.
- **Windows** — `IsolatedWindow` running in the browser process. `ElevatedWindow=true` in manifest so overlays from renderer-hosted content cannot raise above it.
- **Android** — `WindowManager.LayoutParams.TYPE_SYSTEM_ALERT` (or the successor overlay type), hosted from the browser service process.
- **Linux** — GTK `GtkMessageDialog` variant with grab; compositor hint for `dialog` + `modal`.

## Anti-spoof visual identity

The authenticator always displays three elements that web content and extensions cannot fake:

1. **Webkitium lockmark** — an SVG fetched by asset-bundle index (not URL), tinted in the fixed `{brand.accent}` color. The asset index is referenced at compile time; no runtime mutation.
2. **Relying-party origin** in monospace, rendered from the verified origin string (not from renderer-supplied text).
3. **A platform "trusted chrome" affordance** — the window uses the OS-provided trusted-window style (e.g., macOS alert sheet chrome, Windows credential UI chrome) which web content cannot paint.

Users are trained (over time, and with help text in Settings → Passkeys) that these three elements together = real authenticator. Any one of them missing = phish.

## What the password manager inherits

As the authenticator grows into a full password manager (autofill UI, password list, breach check), every surface added gets the same treatment:

- Any new secure surface adds tokens under `tokens/secure-ui/` with `secure-fixed` protection.
- Any new surface is drawn by the browser process, not by a renderer.
- Any new surface carries the lockmark and origin (where applicable).

If a proposed password-manager feature requires embedded web content (e.g., rendering the user's saved site icon), that content is rendered in a **sandboxed renderer with no scripting** and composited into a clipping frame that enforces a minimum margin to the lockmark — preventing visual adjacency that could masquerade.

## What this costs the design system

A small amount of visual coupling: users cannot make the authenticator match their theme. This is a feature, not a bug. Inconsistency between a themeable chrome and a fixed authenticator is a **security signal** — when the user invokes a passkey and a non-themed window appears, they know it's real. If we let the authenticator be themeable, we erase that signal.

## Review bar

Changes under `tokens/secure-ui/`, `components/authenticator/`, or any process-boundary code around the authenticator require security review before merge. The PR template should call out which of the four enforcement layers above the change touches.
