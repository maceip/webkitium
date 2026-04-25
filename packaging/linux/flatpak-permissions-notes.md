# Flatpak / sandbox — WebAuthn + GPU

Add to your Flatpak manifest `finish-args` as needed:

- `--share=network`
- `--socket=wayland` and/or `--socket=fallback-x11`
- `--device=dri` (GPU / WebGPU)
- Bluetooth BLE keys: `--system-talk-name=org.bluez` **or** document that users attach USB authenticators only

Reconcile with **xdg-desktop-portal** availability on the host.
