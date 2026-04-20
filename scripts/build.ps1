<#
.SYNOPSIS
  Trigger a Webkitium build on its GHA runner.

.DESCRIPTION
  PowerShell wrapper for developers on Windows. macOS/Linux devs: use scripts/build.sh.
  Thin wrapper over `gh workflow run`; each platform maps to .github/workflows/<platform>.yml.
  Only platforms with a committed workflow are dispatchable; others return a clear error.

.PARAMETER Platform
  windows | android | linux | macos

.PARAMETER Ref
  Git ref to build. Defaults to current branch.

.PARAMETER SkipPatches
  (windows) Skip webkit/patches and build upstream WebKit only.

.PARAMETER Webgpu
  (windows) Enable --webgpu and experimental features.

.PARAMETER Reuse
  (windows) Reuse existing runner checkout (fast retry).

.PARAMETER Watch
  Stream logs after dispatch.

.EXAMPLE
  .\scripts\build.ps1 -Platform windows
.EXAMPLE
  .\scripts\build.ps1 -Platform windows -Ref codex/fix-xyz -Webgpu -Watch
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$Platform,

  [string]$Ref = '',
  [switch]$SkipPatches,
  [switch]$Webgpu,
  [switch]$Reuse,
  [switch]$Watch
)
$ErrorActionPreference = 'Stop'

$repoRoot = (& git rev-parse --show-toplevel).Trim()
if (-not $repoRoot) { throw "Not inside a git worktree." }

$wf = Join-Path $repoRoot ".github/workflows/$Platform.yml"
if (-not (Test-Path $wf)) {
  $available = Get-ChildItem (Join-Path $repoRoot '.github/workflows') -Filter *.yml -ErrorAction SilentlyContinue |
               ForEach-Object { $_.BaseName }
  throw "No workflow for platform '$Platform' (expected $wf). Available: $($available -join ', ')"
}

if (-not $Ref) { $Ref = (& git -C $repoRoot rev-parse --abbrev-ref HEAD).Trim() }

$inputs = @()
switch ($Platform) {
  'windows' {
    $inputs += @('-f', "skip_repo_patches=$(([bool]$SkipPatches).ToString().ToLower())")
    $inputs += @('-f', "enable_webgpu=$(([bool]$Webgpu).ToString().ToLower())")
    $inputs += @('-f', "reuse_checkout=$(([bool]$Reuse).ToString().ToLower())")
  }
  default {
    # No per-platform inputs defined yet.
  }
}

Write-Host "Dispatching $Platform.yml on ref=$Ref"
& gh workflow run "$Platform.yml" --ref $Ref @inputs
if ($LASTEXITCODE -ne 0) { throw "gh workflow run failed ($LASTEXITCODE)" }

if ($Watch) {
  Start-Sleep -Seconds 3
  $runId = (& gh run list --workflow "$Platform.yml" --limit 1 --json databaseId --jq '.[0].databaseId').Trim()
  if ($runId) {
    & gh run watch $runId
  } else {
    Write-Warning "Dispatched, but could not resolve run id. Check: gh run list --workflow $Platform.yml"
  }
}
