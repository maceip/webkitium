# Config

These files define **AWS regions**, **S3 prefixes**, **builder instance IDs**, and **dependency catalogs** for Webkitium automation.

| File | Role |
|------|------|
| **`build-machines.json`** | Default regions / EC2 instance IDs for Android (SSM), Windows (SSM), macOS (SSM). Overridden by `.env`. |
| **`platforms.json`** | Runner/API: platform status, artifact patterns, Windows WebGPU **presets** (`webgpu-dawn`, `webgpu-dawn-fast`). |
| **`dependencies.json`** | Catalog for `catalog-deps.sh` / `ship-deps.sh`: local paths and S3 prefixes for bootstrap tarballs, AMIs, etc. Paths like `/home/ubuntu/.local/state/webkitium/deps/...` match **builder disk layout** when state uses the default XDG layout. |
| **`changes.json`** | Enabled WebKit integration **lanes** (`changes/<id>/`). See note inside the file: **`windows-webgpu-service`** is **disabled** when that work lives under **`webkit/patches/windows/`**. |
| **`windows-webgpu-dawn-green.json`** | Record of a known-green Windows WebGPU run (AMI, commit, `rootPatchDirectory`: **`webkit/patches/windows`**). |
| **`webkit-build-matrix.json`** | Canonical CI pins (WebKit tarball commit, Dawn/vcpkg baseline, shared CMake toggles). Consumed by workflows and `config/ci_matrix_env.py`. |
| **`packaging-requirements.json`** | Signing env names, min OS versions, permission rationale strings (WebAuthn / Bluetooth), per-platform dependency checklist for shippable binaries. |

**Self-hosted runner images** (sudo, `gh` auth, disk, private-repo checkout) are documented in **`docs/runner-image-requirements.md`**. Run **`scripts/runners/validate-host-prereqs.sh`** on a new builder before registration.

## Environment

**`.env.example`** lists common overrides. Orchestrator and shell scripts load **`.env`** at the repo root when it exists.

### S3 prefix (`webkitium/`)

Default **`NG_ARTIFACT_BUCKET`** and script fallbacks use the top-level prefix **`…/webkitium`** (not the legacy **`…/ng-webkit`** layout). Existing objects under the old prefix keep working if you set **`NG_ARTIFACT_BUCKET`** (and platform overrides such as **`NG_WINDOWS_ARTIFACT_S3`**) to the legacy URL, or after **`aws s3 sync`** from **`ng-webkit/`** to **`webkitium/`** on the same bucket.
