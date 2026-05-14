<img width="599" alt="image" src="https://github.com/user-attachments/assets/e9e1b6a3-a827-4cf8-9390-8258b4ffbad1" />

Browser-on-WebKit monorepo: **orchestrator**, **downstream WebKit** (single patch tree), **per-platform chrome**, **shared portable C++**.

## Layout

| Area | Path |
|------|------|
| Build runner (HTTP API, jobs, logs) | `orchestrator/` |
| WebKit: **all** patches + per-OS scripts + deps | `webkit/patches/`, `webkit/scripts/`, `webkit/deps/` |
| Per-platform chrome / shell (source) | `chrome/<platform>/` |
| Shared C++ (sync, extensions, WebAuthn, …) | `browser/` |
| Config | `config/` |
| Docs | `docs/` |

**Rule:** Patches against the **WebKit checkout** live under **`webkit/patches/`**. Optional **extra** layers (examples: Fluent/Mica MiniBrowser demo, future passkeys stubs) live in **`changes/<lane>/patches/`** and are off by default—see `config/changes.json` and `changes/README.md`. WebGPU/Dawn work was merged into `webkit/patches/windows/`. WebNN/LiteRT-LM integration lives in `changes/webnn-service/`.

**Phases, guardrails, guiding light:** [`docs/DIRECTION.md`](./docs/DIRECTION.md).

## Run a build

```bash
./run-build.sh windows
# canonical: webkit/scripts/common/run-build.sh
```

Drivers live under **`webkit/scripts/<os>/`** (not a separate `platforms/` tree).

Orchestrator: `cd orchestrator && npm install && npm start` — see **`docs/policy/RUNNER.md`**, **`orchestrator/RUNNER_API.md`**.

## Patches and config

- Windows **lane** + **baseline** patches are one ordered series under `webkit/patches/windows/` (WebGPU series first, then follow-on fixes).
- Policy and runbooks live under **`docs/policy/`** (not scattered at repo root).
- **`config/build-machines.json`**, **`platforms.json`**, **`dependencies.json`**, **`.env.example`** describe builders, regions, and artifact layout. See **`config/README.md`**.
- **`config/changes.json`** defines optional **`changes/<lane>/`** layers (mostly **off**); **`windows-webgpu-service`** stays **disabled** when the same work lives under `webkit/patches/windows/`.
