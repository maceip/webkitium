# Windows packaging

- **Signing:** `signtool sign /fd SHA256 /a your.exe` after build; EV cert for reputation.
- **WebAuthn:** Uses OS **Windows.Web.UI** / WebAuthn APIs — no Bluetooth capability in classic Win32 manifest; USB/NFC/Platform keys handled by OS.
- **Manifest:** Embed `webkitium.exe.manifest` via linker `/MANIFEST:EMBED` or `mt.exe` for DPI awareness.
