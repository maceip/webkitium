# Product packaging scaffolding

Templates and manifests for **signed binaries**, **OS permission strings**, and **dependency checklists**. Replace placeholders (`ORG.WEBKITIUM`, `Webkitium`) before shipping.

Canonical policy and signing env names: **`config/packaging-requirements.json`**.

| Directory | Role |
|-----------|------|
| `macos/` | `Info.plist` keys + `.entitlements` for WebAuthn / passkeys / Bluetooth |
| `ios/` | Same for iOS; device builds need provisioning (see JSON) |
| `android/` | Manifest **fragments** to merge into WPE-Android `AndroidManifest.xml` |
| `linux/` | `.desktop` + AppStream metadata for portals / GPU / Bluetooth |
| `windows/` | Win32 `.manifest` template for version + DPI awareness |

CI baseline zips still come from `.github/workflows/*`; these files feed **real product packaging** (DMG/PKG, IPA, signed APK, MSI, deb/Flatpak).
