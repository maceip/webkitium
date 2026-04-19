# Direction — where Webkitium is going

This is the **forward view**: what we’re moving toward, in what order, and what we won’t compromise. For folder layout, see [`ARCHITECTURE.md`](ARCHITECTURE.md). For build mechanics, see [`policy/BUILD_LAW.md`](policy/BUILD_LAW.md).

---

## Guiding light

**Ship a credible multi‑platform browser on WebKit** with:

- **Repeatable downstream builds** of WebKit/WPE on every target OS (the cost of admission).
- A **portable product layer** (sync, extensions, WebAuthn, tabs) that is **not** tangled with “make the engine compile.”
- **Per‑platform chrome** where native UI and OS glue live—developed deliberately, not as throwaway MiniBrowser hacks.
- A **runner** that turns builds into a **known, observable pipeline** (ids, logs, artifacts)—suitable to expose as a service later.

The repo should read as **one coherent product**, not a pile of experiments with unclear ownership.

---

## Phases (rough order)

Phases overlap in time; later phases assume earlier ones don’t regress.

| Phase | Focus | “Done enough” looks like |
|-------|--------|---------------------------|
| **1 — Downstream WebKit** | Pinned trees, **`webkit/patches/`**, **`webkit/scripts/`**, green builds per OS, artifacts + logs you trust | You can answer “what commit + what patches produced this binary?” without archaeology |
| **2 — Orchestration** | **`orchestrator/`**, same entrypoints from CLI and API, stable artifact layout | Builds are **tracked** (ids, status, checkpoints), not only “it worked on my machine” |
| **3 — Portable core** | **`browser/`** wired into real build(s); sync / extensions / WebAuthn **contracts** stable | Shared C++ is **in the product path**, not only reference code |
| **4 — Per‑platform chrome** | **`chrome/<os>/`** shells that consume the portable core via clear adapters | Each OS has a **maintainable** shell; experiments are **named**, testable, and don’t pollute `webkit/patches/` |
| **5 — Hardening** | CI, signing, update, perf, security review | Same story on every OS you care to ship |

Windows WebGPU/Dawn is **one track inside phase 1**, not a substitute for the rest.

---

## Guardrails

**Separation**

- **Engine patchability** lives under **`webkit/patches/`** only. Do not add a second “patches” tree for WebKit diffs.
- **Product / chrome** does not hide inside endless WebKit patches—use **`browser/`**, **`chrome/`**, or a **`changes/`** lane with intent and an owner.
- **Orchestration** (`orchestrator/`) does not absorb engine or product source.

**Quality**

- No **untested** per‑platform chrome landing as “always on.” Toggle via **`config/changes.json`**, document the lane, add the checks you need before enabling by default.
- **Reproducibility:** pinned upstream, ordered patches, scripted drivers—see **`policy/BUILD_LAW.md`**. Remote‑only edits are not the source of truth.

**Process**

- Prefer **one obvious place** for each concern over new top‑level buckets. If something doesn’t fit, **name the gap** and extend the map—don’t sprawl.
- **Docs** explain *why* and *where*; they don’t replace scripts. Avoid duplicate “project overview” pages that go stale.

---

## Moving on from here

- **Carry forward:** the **layout** (orchestrator / webkit / chrome / browser), the **single WebKit patch tree**, and the **runner + patch pipeline** as the spine of the project.
- **Leave behind:** ambiguous dual patch roots, chrome experiments without tests, and long **historical** build narratives in policy docs—keep policy **short** and **current**.
- **Next concrete step** is usually: **keep phase 1 green** on the platforms you care about, then **tighten orchestration** and **attach the portable core** to a real build when you’re ready—not the other way around.
