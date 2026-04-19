# WebKit NG — repository architecture

**Webkitium** is the **authoritative source** for **WebKit NG**: the browser product, its portable layers, and **repeatable builds** of downstream WebKit for **Android**, **iOS**, **Linux**, **macOS**, and **Windows**. Windows WebGPU/Dawn is one **lane**, not the whole project.

**Full doc index:** [`README.md`](README.md) (this folder).

## Four pillars (folder semantics)

This repo is organized around **four separable concerns**. Paths below are **today’s layout**; the names are stable even when some trees are still reference-only (not yet on your product build).

### 1. Build runner / orchestrator

**What it is:** The **control plane** that starts builds, assigns **build ids**, streams logs, checkpoints, and artifacts—what can later be exposed as a **public build site**.  
**Where:** **`orchestrator/`**, **`webkit/scripts/common/`** (e.g. `run-build.sh`), **`config/`**, plus policy docs under **`docs/policy/`** (`RUNNER.md`, `BUILD_LAW.md`, `ASSETS.md`, `STATUS.md`, …).

### 2. Per-platform WebKit patches (downstream compiles)

**What it is:** Everything that makes **upstream WebKit (or WPE) build and run** on a given OS—toolchain fixes, CMake, and always-on plumbing. This is **not** the product browser UI; it is **engine + integration** for that platform’s tree.  
**Where:** **`webkit/patches/<platform>/`**, **`webkit/patches/common/`**, and **`webkit/scripts/<os>/`** (Gradle, SSM, runbooks). Some platforms lean on **integration** more than a long patch list (e.g. Android-style flows); that still lives conceptually here.

### 3. Per-platform chrome / shell

**What it is:** **Platform-specific UI and glue** around the engine—distinct from the portable C++ core. **Long-lived source** belongs under **`chrome/<platform>/`**. Optional WebKit‑side experiments can use **`changes/<lane>/`** (toggle in `config/changes.json`); see [`changes/README.md`](../changes/README.md).

### 4. Shared portable C++ core (product browser)

**What it is:** The **cross-platform browser layer** intended to be shared across OSes: **sync**, **extensions**, **WebAuthn**, tabs, protocols—**not** “make WebKit compile” (that is pillar 2).  
**Where:** **`browser/`** (including `sync/`, `extensions/`, `webauthn/`, …). Vendored protocol or reference trees (e.g. sync) live under **`browser/third_party/`** when present.

---

## What lives here (paths)

| Pillar | Path | Role |
|--------|------|------|
| **Orchestrator** | **`orchestrator/`**, **`config/`**, **`docs/policy/`** (`RUNNER.md`, `ASSETS.md`, …) | Build API, runner, artifacts, policy. |
| **WebKit patches** | **`webkit/patches/<platform>/`**, **`webkit/patches/common/`**, **`webkit/scripts/<os>/`** | Downstream WebKit/WPE buildability per OS. |
| **Per-platform chrome** | **`chrome/<platform>/`**; optional **`changes/<lane>/`** for WebKit‑side experiments | Native shell source vs toggleable lane patches. |
| **Portable C++ core** | **`browser/`** | Shared product code: sync, extensions, WebAuthn, tabs; optional `third_party/` under this tree. |
| **Docs** | **`docs/`** | Focused program docs (e.g. WebGPU milestones). |

Apply order is defined in **`webkit/scripts/`**: enabled **`changes/`** lanes first (if any), then **`webkit/patches/`**. Keeps optional work toggleable without forking the main patch series.

## Documentation layers

| Layer | Purpose |
|-------|---------|
| **Root + `docs/policy/`** (`README`, `BUILD_LAW`, `RUNNER`, `ASSETS`, …) | Repo-wide policy, orchestration, artifacts. |
| **`docs/`** | Focused program docs (e.g. [`WEBGPU_PROGRAM.md`](WEBGPU_PROGRAM.md)). |
| **`changes/<lane>/`** | Lane-specific scope, design, green baselines next to that lane’s patches. |

## Build flow (conceptual)

`POST /builds` (or `./run-build.sh` / `webkit/scripts/common/run-build.sh`) → runner records **build id** → `webkit/scripts/<os>/build.sh` → remote builder (e.g. SSM) → **S3 artifacts** + validation JSON. Details: [`policy/RUNNER.md`](policy/RUNNER.md), [`policy/ASSETS.md`](policy/ASSETS.md).

## See also

- [`README.md`](../README.md) — entry by role, targets, how to run a build.
- [`policy/STATUS.md`](policy/STATUS.md) — recent build outcomes (rotating log).
- [`DIRECTION.md`](DIRECTION.md) — phases, guardrails, guiding light.
