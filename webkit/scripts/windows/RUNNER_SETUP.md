# GitHub Actions self-hosted runner — one-time setup

**Goal:** register the existing Windows EC2 builder as a GitHub Actions self-hosted runner so `.github/workflows/windows.yml` can dispatch WebKit builds without SSM.

**Run by:** a human operator, once per builder, via **RDP** or **EC2 Instance Connect**. **Do not** automate these steps through SSM.

**Pre-requisite:** `setup-deps.ps1` has already been applied on this host (Git, LLVM, CMake, Ruby, Python, VS Build Tools, vcpkg, sccache present under `C:\Bootstrap\`).

---

## 1. Generate a registration token (GitHub side, ~30 seconds)

1. Open the repo on GitHub: **Settings → Actions → Runners**.
2. Click **New self-hosted runner** → **Windows** → **x64**.
3. Copy the `--token` value from the page. It's single-use and **expires in about one hour**, so do the rest of this runbook in the same sitting.
4. Keep that browser tab open — it also shows the runner tarball URL and version pinned to what the repo expects.

## 2. Connect to the EC2 builder

- RDP to the instance (default `i-05ab9a8ed6d325b3d` per `webkit/scripts/windows/build.sh`), or use **EC2 Instance Connect → RDP**.
- Open an **Administrator** PowerShell (`Start → PowerShell → Run as administrator`).

## 3. Install the runner as a Windows service

Paste the block below, replacing the three placeholders:

- `<OWNER>` / `<REPO>` — the GitHub repo (e.g. `Webkitium/Webkitium`).
- `<TOKEN>` — from step 1.
- `<RUNNER_VERSION>` — from the GitHub "New runner" page (e.g. `2.320.0`). Keep the version pinned so auto-update can't regress unexpectedly; GHA will auto-update later anyway.

```powershell
$ErrorActionPreference = 'Stop'

$RunnerRoot = 'C:\actions-runner'
$Version    = '<RUNNER_VERSION>'
$Owner      = '<OWNER>'
$Repo       = '<REPO>'
$Token      = '<TOKEN>'

# Hostname-derived runner name so the GHA UI shows a meaningful label.
$RunnerName = "$env:COMPUTERNAME-webkitium"

New-Item -ItemType Directory -Force -Path $RunnerRoot | Out-Null
Set-Location $RunnerRoot

$tarball = "actions-runner-win-x64-$Version.zip"
if (-not (Test-Path $tarball)) {
  Invoke-WebRequest -Uri "https://github.com/actions/runner/releases/download/v$Version/$tarball" -OutFile $tarball
}

# Clean prior install if re-registering.
if (Test-Path "$RunnerRoot\config.cmd") {
  & "$RunnerRoot\config.cmd" remove --token $Token 2>$null
}
Get-ChildItem $RunnerRoot -Exclude $tarball | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

Expand-Archive -Path $tarball -DestinationPath $RunnerRoot -Force

& "$RunnerRoot\config.cmd" `
    --url "https://github.com/$Owner/$Repo" `
    --token $Token `
    --name $RunnerName `
    --labels "self-hosted,windows,webkitium" `
    --work "_work" `
    --runasservice `
    --unattended `
    --replace
```

The labels `self-hosted`, `windows`, `webkitium` are what `.github/workflows/windows.yml` targets via `runs-on: [self-hosted, windows, webkitium]`. If you change them here, change the workflow too.

## 4. Verify

In the same PowerShell:

```powershell
Get-Service actions.runner.* | Format-Table Name, Status, StartType
```

You should see one service in `Running` / `Automatic`. Back in the GitHub UI (**Settings → Actions → Runners**) the new runner should appear with a green **Idle** badge within ~10 seconds.

## 5. Trigger a test build

From a Linux / Mac shell with `gh` authenticated:

```bash
gh workflow run windows.yml --ref master \
  -f skip_repo_patches=false \
  -f enable_webgpu=false \
  -f reuse_checkout=false
```

Or in the GitHub UI: **Actions → Windows build → Run workflow**.

Watch it under **Actions → Windows build**. First green run means the migration is live. The legacy path (`orchestrator/`, `ssm-worker.ps1`, `build.sh` SSM bootstrap) stays in the tree until you're confident; retire it separately.

---

## Rotating / removing the runner

- **Re-register** (e.g. token expired mid-install): generate a fresh token (step 1) and re-run the block in step 3 — it has `--replace` so it idempotently re-registers.
- **Remove cleanly**: generate a **removal token** from the same GHA Runners page, then on the host:
  ```powershell
  & 'C:\actions-runner\config.cmd' remove --token <REMOVAL_TOKEN>
  ```
  That stops the service, unregisters from GitHub, and leaves the directory removable.

## Notes

- The runner process runs as **LocalSystem** by default (service install). WebKit's build consumes lots of disk and memory; this account has the access it needs without extra permission work.
- sccache keeps its cache at `C:\Bootstrap\sccache` across runs — self-hosted persistence is the main reason to use a long-lived EC2 runner rather than `windows-latest`.
- The workflow's `concurrency` group cancels in-progress builds on the same ref when a new push arrives, so iterative agent debug loops don't queue up. Different refs serialize at the runner (single builder) rather than cancelling each other.
- **No SSM involved.** GitHub Actions pulls jobs from the repo over HTTPS; nothing on the Linux side dispatches remote commands.
