# BUILD LAW

Build harness for **Webkitium**: cross-platform WebKit builds from one entrypoint.

- **Entrypoint:** `./run-build.sh <platform> <id>` (repo root wrapper) or **`webkit/scripts/common/run-build.sh`**.
- **WebKit patches:** only under **`webkit/patches/<platform>/`** and **`webkit/patches/common/`** (see root `README.md`). Optional lanes under **`changes/`** apply first when enabled in **`config/changes.json`**.
- **Orchestrator:** HTTP API and dashboard live under **`orchestrator/`** (not in this document).

Upstream WebKit is a **separate** clone from this repo; builds apply this repo’s patch series to a pinned commit.

---

## Priority

1. Drive the **Windows** build **green** using the standard entrypoint only: `./run-build.sh windows <id>` or **`webkit/scripts/common/run-build.sh windows <id>`** — fix blockers with **ordered** patches under **`webkit/patches/windows/`** (and **`webkit/patches/common/`** when shared).
2. After green, align scripts, env samples, and docs with that harness without letting harness churn replace compile/link fixes.

### Windows fix loop (until green)

1. A build error appears (driver log, remote log, `BUILD_FAILED.txt`, or S3 artifacts).
2. Capture the **last ~10 substantive** error lines from the log.
3. Fix by extending **numbered** patches under **`webkit/patches/windows/`** (and common when needed). No `.rej` files; normalize before the next run.
4. **Rebuild** with `./run-build.sh windows <new-id>` (or `webkit/scripts/common/run-build.sh`). Repeat until green.

---

## Reproducibility (what “accepted” means)

A build is only **accepted** if it can be recreated from:

1. A **pinned** WebKit git URL and commit SHA  
2. **Ordered patches** stored in this repository (`webkit/patches/`, plus enabled `changes/` lanes if any)  
3. **Documented** toolchain paths (compiler, CMake, Ninja, etc.) — see platform runbooks  
4. **Scripted** driver commands (`webkit/scripts/<platform>/`, not one-off remote edits)  
5. **Uploaded** logs, manifests, and artifacts where your process requires them  

**Do not** treat remote-only edits, dirty trees, or undocumented commands as the definition of a good build.

### Before starting a build, record

- WebKit remote URL and commit SHA  
- Patch list (and hashes if your manifest requires them)  
- Builder identity: instance/region or local host, and relevant env (see `.env.example`)  
- S3 or artifact prefix if applicable  

### Patch layout

- Patches apply in **sorted filename order** within each directory.  
- Use a numeric prefix: e.g. `0001-…`, `0002-…`.  
- **Windows:** `webkit/patches/windows/*.patch` (plus `webkit/patches/common/` when shared).  

### Clean build discipline

1. Clean or dedicated source checkout for the pinned commit.  
2. Apply patches in order; **fail** if `git apply` leaves **`.rej`** files.  
3. Do not accept unexpected dirty trees after apply (except known generated noise).  
4. Use **sparse checkout** only when documented for that platform; record sparse roots in the driver script.  
5. Build via the repo’s **`build.sh`** / remote bundle for that platform — not ad hoc remote-only recipes.  

### Gates (automated)

The platform scripts should enforce at least: correct **HEAD**, no **`.rej`**, expected **CMake** flags for the target (e.g. Win port, MiniBrowser, WebGPU when in scope), and expected **binaries** present in the output (e.g. `MiniBrowser.exe` on Windows). Exact checks live in **`webkit/scripts/windows/remote-build.ps1`** and peers — keep them aligned with this law.

### Manual checks (when required by the lane)

On Windows WebGPU lanes, typical acceptance includes launching **MiniBrowser**, basic navigation, **Show Inspector**, and a **WebGPU/Dawn** smoke consistent with the enabled feature set. Record outcomes in your manifest or runbook.

### Prohibited shortcuts

- Patching on the builder **without** landing the same change as a repo patch.  
- Accepting a **dirty** or **unpinned** tree as the source of truth.  
- Treating **configure success** alone as proof of WebGPU or inspector behavior.  
- Calling a build “done” without the checks your lane requires.

---

## See also

- [`RUNNER.md`](RUNNER.md) — runner and API  
- [`ASSETS.md`](ASSETS.md) — artifact layout  
- [`../ARCHITECTURE.md`](../ARCHITECTURE.md) — repo layout  
- Platform runbooks under **`../../webkit/scripts/<os>/`**
