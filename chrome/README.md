# Per-platform chrome

Native shell and browser chrome around the engine: one subdirectory per OS. Source and resources for that platform's UI and glue live here, not in upstream WebKit patches.

The goal is native product quality per platform while preserving a shared browser model:

- Tabs: same lifecycle, restoration, pinned-state, title, favicon, loading, and close semantics.
- Location: same canonical URL/search handling, security state, permission affordances, and page identity.
- Commands: same command IDs for navigation, tab management, find, share, downloads, settings, and developer tools.
- Prompts: native presentation, shared decisions for permissions, WebAuthn/passkeys, downloads, certificates, and dangerous navigation.
- State: platform UIs bind to the same portable state snapshots instead of inventing separate browser behavior.

MiniBrowser is only a bring-up tool. Product chrome should be native: SwiftUI/AppKit on macOS, Jetpack Compose on Android, WinUI 3 on Windows, and a Linux-native shell when Linux becomes product scope.

See [NATIVE_CHROME.md](NATIVE_CHROME.md) for the current platform direction and candidate upstream projects.
