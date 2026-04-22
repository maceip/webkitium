# WebKit integration lanes (`changes/`)

Optional, **toggleable** patch bundles applied to the WebKit checkout **before** **`webkit/patches/`** (see root `README.md`). Enable in **`config/changes.json`**.

## Examples in this repo

| Lane | Purpose |
|------|---------|
| **`windows-minibrowser-fluent-tabs/`** | **Reference:** Windows 11 Fluent / Mica styling in MiniBrowser and tab wiring—see lane `README.md`. Off by default. |
| **`passkeys-credentials-get/`** | **Stub:** placeholder dirs for future `navigator.credentials.get` / passkey WebKit patches (`.gitkeep` only until you add `.patch` files). Off by default. |
| **`windows-webgpu-service/`** | Docs only here; WebGPU/Dawn patches were merged into **`webkit/patches/windows/`**. |
| **`webnn-service/`** | WebNN (`navigator.ml`) integration using platform ML backends (ONNX Runtime, Core ML, TFLite). Off by default. |

Create a lane:

```bash
./webkit/scripts/common/new-change.sh <change-id>
```
