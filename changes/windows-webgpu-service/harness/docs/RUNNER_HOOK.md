# Runner hook — contract and drop-in integration

The local tree does not currently have the `orchestrator/` directory the
root README references. That's OK: the harness ships a file-level contract
the runner can adopt when it comes back, regardless of which language/shape
the runner takes.

## Contract

Every WebGPU-on-Windows build in the runner should, at validation time,
produce **one** `validation-report.json` at the artifact root. The shape is:

```jsonc
{
  "runtime": {
    "gpuAvailable": bool,
    "queueAvailable": bool,
    "adapter":        { "backend": str, "vendor": str, "device": str, ... } | null,
    "surface":        { "configured": bool, "format": str | null },
    "render":         { "framesSubmitted": int, "framesPresented": int, "lastError": str | null },
    "probes":         { "<name>": { "ok": bool, "detail": str, ...extra } },
    "overallOk":      bool,
    "sources":        { "harness": path, "browser": path | null }
  }
}
```

Probe keys use a prefix for provenance:
- `harness.<name>` — from `webgpu_host.exe --probe --suite all`.
- `<name>` (no prefix) — from `validate-probe.html` under MiniBrowser.

The runner must mark `overallOk = true` only when every probe from **both**
families passed. If MiniBrowser isn't available on the builder yet, the
browser probes are omitted but harness probes still run; that's a signal
that Dawn is healthy but the browser goalposts are unverified.

## Drop-in scripts

Three files under `changes/windows-webgpu-service/harness/tools/`:

1. **`validate-probe.html`** — self-contained page. Run under any build of
   MiniBrowser that has `WebGPUEnabled` set (patch 0032). Writes its JSON
   into `#validation-report`.
2. **`merge-reports.ps1`** — takes the harness JSON + the scraped browser
   JSON, produces the unified report above. Exit 0 iff `overallOk`.
3. **`run-goalposts.ps1`** — the full loop: stage-1 harness probes, stage-2
   MiniBrowser run (if supplied), stage-3 merge. Exits non-zero if any
   piece failed.

## Runner integration points

When the orchestrator returns, three hooks use the contract:

### Hook 1: after build success, before artifact upload

```bash
pwsh ./changes/windows-webgpu-service/harness/tools/run-goalposts.ps1 `
     -Harness "$BUILD_OUT/webgpu_host.exe" `
     -MiniBrowser "$BUILD_OUT/bin64/MiniBrowser.exe" `
     -OutDir "$BUILD_OUT/goalposts"
cp "$BUILD_OUT/goalposts/validation-report.json" "$ARTIFACT_ROOT/validation-report.json"
```

This replaces whatever the runner previously wrote as
`validation-report.json`.

### Hook 2: harness-only fast path

Use when we want a validation signal without a completed WebKit build —
e.g., CI on the harness subrepo, or a smoke pass after a Dawn pin bump:

```bash
pwsh ./changes/windows-webgpu-service/harness/tools/run-goalposts.ps1 `
     -Harness "$BUILD_OUT/webgpu_host.exe" `
     -NoWindow `
     -OutDir "$BUILD_OUT/goalposts"
```

`overallOk` here means "Dawn works on this box"; browser goalposts remain
unverified.

### Hook 3: browser-only via WebDriver/inspector

Once MiniBrowser supports an automation hook (WebKit's Remote Inspector,
or AutomationClient), stage 2 in `run-goalposts.ps1` can scrape
`#validation-report` without manual intervention. Until then stage 2 is
best-effort: it launches MiniBrowser, waits, kills it, and merges whatever
JSON happened to land. That is acceptable for bring-up but not CI.

## What the runner must *not* do

- **Not** embed the probe logic. If the runner re-implements what
  `validate-probe.html` does, the contract drifts and cross-host
  comparison breaks. Keep the page + harness binary as the single sources
  of truth; the runner just sequences them.
- **Not** mutate `validation-report.json` post-merge. Add fields under
  `runner` at the top level if the runner wants to record build metadata;
  do not edit `runtime.*`.

## Versioning

Bump the JSON root to `{ "schemaVersion": N, "runtime": {...} }` only when
a breaking change lands. Today the report is implicitly v1. Keep adding
fields freely at any depth — consumers should tolerate unknown keys.
