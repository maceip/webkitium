# Downstream WebKit

Everything needed to **check out, patch, and build** WebKit (or WPE) per OS.

- **`patches/<platform>/`** — Ordered `.patch` series for that platform; `common/` when shared across platforms. This is the **only** place in the repo for patches against the WebKit tree.
- **`scripts/<platform>/`** — Local and CI drivers (SSM, Gradle, etc.).
- **`deps/`** — Pins, lockfiles, overlays, toolchain notes.

Apply order, pinned upstream revision, and sparse-checkout policy should be documented here as they solidify.

**Windows:** `patches/windows/` contains a **single** ordered series (former WebGPU lane patches **then** former root baseline patches), `0001`–`0031` — see repo migration notes in the root `README.md`.
