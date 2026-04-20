# Windows builder — compliance, caching, reporting

> **Migration notice (2026-04-20).** The SSM + `ssm-worker.ps1` + `orchestrator/` dispatcher described in sections 4–6 is being **retired**. New builds run through the GitHub Actions self-hosted runner defined in **`.github/workflows/windows.yml`**; one-time runner setup is in **`webkit/scripts/windows/RUNNER_SETUP.md`**. Trigger with `scripts/build.sh -p windows` (macOS/Linux), `scripts\build.ps1 -Platform windows` (Windows), or `gh workflow run windows.yml`. The `setup-deps.ps1` compliance path (section 1) and the `remote-build.ps1` compile driver still apply — only the dispatcher changed.

**Purpose:** One place for **how** a Windows EC2 (or VM) used for Webkitium gets **into spec**, how builds **run**, and how **success/failure** is reported. **No narrative history**—only what you do **now**.

**Dashboard / API (legacy):** Start and watch builds through **`orchestrator/src/server.js`** (`GET /`, `POST /builds`) — see **`RUNNER.md`** (under `docs/policy/`). Prefer the GHA path above; this path will be removed after the GHA runner is green.

---

## 1. Compliance path (~10 minutes hands-on + SSM run)

**Goal:** Git, LLVM, CMake, Ruby, VS Build Tools, vcpkg, gperf, sccache, paths — **idempotent**, **scripted**.

1. **Instance:** SSM **Online** (`NG_WINDOWS_INSTANCE_ID` in `.env` or `config/build-machines.json`).
2. **From the repo root** (Linux/Mac with AWS CLI):

   ```bash
   export NG_WINDOWS_INSTANCE_ID=i-xxxxxxxx   # your builder
   ./webkit/scripts/windows/setup-deps.sh
   ```

   This uploads and runs **`setup-deps.ps1`** on the host (Administrator/SYSTEM). It is **the** supported path—**not** manual installs of Git/Ruby/etc.

3. **Verify:** Script ends without throw; transcript under **`C:\Bootstrap\setup-deps-*.log`**. (Provisioning also logs **C: free GiB** at start.)

**If `setup-deps` fails:** Fix **`setup-deps.ps1`** or **`setup-deps.sh`**, re-ship—do **not** “fix” the machine by hand and leave the repo wrong.

**Note:** **`build.sh`** runs **`setup-deps.sh`** automatically before staging patches (stdout discarded on the driver); if provisioning fails, the **Windows build exits** before SSM.

---

## 2. Disk space (fail fast)

WebKit + vcpkg + sccache + checkout trees fill disks quickly. **Silent full-disk** runs waste hours and can wedge the instance.

- **Before clone/build:** **`remote-build.ps1`** runs **`Assert-DiskHeadroom`** on **C:** and on every drive letter used by these **`build-config.json`** paths (when set): **`workdir`**, **`vcpkgRoot`**, **`cleanSourceRoot`**, **`legacySourceRoot`**, **`outputDir`**, **`bootstrap`**, and (if sccache enabled) **`sccacheDir`**.
- **Default minimum:** **50 GiB** free per checked drive — override with **`NG_WINDOWS_MIN_FREE_GB`** → **`build-config.json`** **`minFreeGiB`** (wired in **`build.sh`**).
- If the check fails, the build throws **immediately**—**not** after a long compile.

**When full:** Remove old trees under **`C:\W\`**, prune **vcpkg** buildtrees if safe, stop sccache and trim **`C:\Bootstrap\sccache`**, or **expand the volume**—then re-run.

---

## 3. Caching (required)

- **`build.sh`** defaults **`NG_WINDOWS_ENABLE_SCCACHE=1`**. Disabling requires **`NG_WINDOWS_ALLOW_SCCACHE_OFF=1`** (emergency only).
- **`remote-build.ps1`**: starts **sccache** when enabled; after compile, verifies CMake/ninja use **`sccache`** and writes **`artifacts/sccache-report.json`** (throws if misconfigured — see **`webgpu-dawn-runbook.md`**).

---

## 4. Reporting truth (what “done” means)

Markers are written by **`ssm-worker.ps1`** in **`WorkDir`** (not by **`remote-build.ps1`** alone).

| Signal | Written by | Meaning |
|--------|------------|---------|
| **`BUILD_FAILED.txt`** | **`ssm-worker.ps1`** (catch or finally) | Failure — read body + **`worker-output.log`** + service log. |
| **`BUILD_READY.txt`** | **`ssm-worker.ps1`** | **`remote-build.ps1`** completed successfully; **`aws s3 sync`** of **`artifacts/`** runs **next**. |
| **`BUILD_DONE.txt`** | **`ssm-worker.ps1`** | **`s3 sync` finished** — use this for “artifacts uploaded,” not “compile looked OK.” |

Use **`GET /builds/:id/logs/windows`** on the runner to tail progress.

---

## 5. Kicking a build

```bash
curl -X POST http://localhost:8787/builds \
  -H 'content-type: application/json' \
  -d '{"platforms":["windows"],"reason":"windows sanity","presets":{"windows":"webgpu-dawn"}}'
```

Or **`./webkit/scripts/common/run-windows-webgpu-dawn.sh <id>`** — wrapper that sets WebGPU preset + **`NG_WINDOWS_ENABLE_SCCACHE=1`**, then **`run-build.sh windows`**.

**MiniBrowser gradient relaunch (short-path `C:/W/`, 2026-04-19):** use preset **`minibrowser-gradient-retry`** (see **`config/platforms.json`**) or the same keys via **`platformEnv`**. That keeps **`NG_WINDOWS_ENABLE_SCCACHE=1`**, **`NG_WINDOWS_REUSE_CHECKOUT=1`**, **`NG_WINDOWS_PRESERVE_BUILD_DIR=0`**, pins **`NG_WINDOWS_CLEAN_SOURCE`** to the builder tree (sccache variant by default; override to **`C:/W/minibrowser-gradient-cmakeargs-20260419`** for the other run), and bundles **`0022` + `0034` + `0091`–`0094`** via **`NG_WINDOWS_ROOT_PATCH_FILTER`** (gradient patch plus Windows compile-command rewrite and format-attribute hygiene patches). **`build.sh`** already folds the required **`build-webkit --cmakeargs`**: **`clang-cl`** under **`C:/Progra~1/LLVM/bin/`** and **`CMAKE_*_COMPILER_LAUNCHER`** as **`C:/Bootstrap/toolbin/sccache.exe`** when sccache is on. Runbook: **`docs/policy/MINIBROWSER_GRADIENT_BUILD_RUNBOOK.md`**.

**Upstream-only (no repo patches):** set **`NG_WINDOWS_SKIP_REPO_PATCHES=1`** in **`platformEnv.windows`** (or export before **`build.sh`**). The SSM bundle still ships **`remote-build.ps1`**, but **`patches/common`** and **`patches/windows`** are empty so **`remote-build.ps1`** applies nothing—compile is the pinned WebKit tree as cloned.

---

## 6. Script inventory (audited)

| Script | Role (verified in repo) |
|--------|-------------------------|
| **`setup-deps.sh`** | Wraps AWS SSM: uploads **`setup-deps.ps1`**, runs it on **`NG_WINDOWS_INSTANCE_ID`**. |
| **`setup-deps.ps1`** | Idempotent toolchain install (Git, VS Build Tools, Ruby, Python, CMake, LLVM, vcpkg, gperf, sccache, paths). Requires **Admin**. Logs **C: free GiB** at start; transcript **`C:\Bootstrap\setup-deps-*.log`**. |
| **`build.sh`** | Requires **sccache** unless bypass; calls **`setup-deps.sh`**; stages patches + **`remote-build.ps1`** + **`ssm-worker.ps1`**; writes **`build-config.json`** (**`minFreeGiB`**, **`enableSccache`**, paths); uploads bundle; **SSM bootstrap** starts detached worker. |
| **`remote-build.ps1`** | **`Assert-DiskHeadroom`**; clone/sparse checkout; **`Ensure-Sccache`**; **WebKit compile**; local **`artifacts/`**; **`sccache-report.json`** validation when sccache on. |
| **`ssm-worker.ps1`** | **`Unblock-File`**; runs **`remote-build.ps1`**; **`BUILD_READY.txt`** → **`aws s3 sync`** → **`BUILD_DONE.txt`** or **`BUILD_FAILED.txt`**; **`worker-output.log`** transcript; **finally** writes **`BUILD_FAILED.txt`** if no marker. |
| **`webkit/scripts/common/run-build.sh`** (or **`./run-build.sh`** at repo root) | Entry for **`POST /builds`** / CLI: routes to **`webkit/scripts/windows/build.sh`**. |
| **`scripts/run-windows-webgpu-dawn.sh`** | Sets WebGPU env defaults, calls **`run-build.sh windows`**. |
| **`webgpu-dawn-runbook.md`** | WebGPU/Dawn lane: DLLs, validation JSON, sccache checks. |

---
