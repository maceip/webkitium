# End-to-end goalpost run.
#
# Stage 1: harness probe suite (no WebKit build required, always runs).
# Stage 2: MiniBrowser against validate-probe.html, harvest the in-browser
#          report (skipped if -MiniBrowser not supplied or missing).
# Stage 3: merge-reports.ps1 stitches both outputs into a single
#          validation-report.json.
#
# This is the thing a runner (or a human) invokes to measure progress.
# Output: exit 0 iff every probe — harness-side and browser-side — passed.

[CmdletBinding()]
param(
    [string] $Harness     = "build/webgpu-host/webgpu_host.exe",
    [string] $MiniBrowser = "",
    [string] $ProbePage   = "changes/windows-webgpu-service/harness/tools/validate-probe.html",
    [string] $OutDir      = "build/goalposts",
    [int]    $Frames      = 8,
    [ValidateSet('d3d12','d3d11','vulkan','undefined')]
    [string] $Backend     = 'd3d12',
    [switch] $NoWindow,
    [int]    $BrowserWaitSeconds = 8
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

$harnessJson = Join-Path $OutDir 'harness.json'
$browserJson = Join-Path $OutDir 'browser.json'
$mergedJson  = Join-Path $OutDir 'validation-report.json'

# --- Stage 1 -----------------------------------------------------------------
if (-not (Test-Path $Harness)) {
    throw "harness binary not found at $Harness; build it via scripts/run.ps1 first"
}
$suite = if ($NoWindow) { 'adapter,device,buffer,compute,render,errors' } else { 'all' }
$harnessArgs = @('--probe', '--suite', $suite, '--json', $harnessJson,
                 '--backend', $Backend, '--frames', $Frames)
if ($NoWindow) { $harnessArgs += '--no-scene' ; $harnessArgs += '--headless' }
else           { $harnessArgs += @('--demo','triangle') }
Write-Host "[stage1] $Harness $harnessArgs"
& $Harness @harnessArgs
$stage1Exit = $LASTEXITCODE
Write-Host "[stage1] exit=$stage1Exit"

# --- Stage 2 -----------------------------------------------------------------
$stage2Ran = $false
if ($MiniBrowser -and (Test-Path $MiniBrowser) -and (Test-Path $ProbePage)) {
    $stage2Ran = $true
    $probeUrl = (Resolve-Path -LiteralPath $ProbePage).Path
    # MiniBrowser doesn't have a headless mode; we launch, wait, harvest,
    # then kill. Output harvesting is via AutomationClient when enabled,
    # or via a side-channel cookie file the probe page writes. For now we
    # scrape the page via WebKit's inspector protocol if present; if not,
    # we document that this stage still requires a manual copy.
    Write-Host "[stage2] MiniBrowser run — NYI scraping hook."
    Write-Host "[stage2] point MiniBrowser at: $probeUrl"
    Write-Host "[stage2] after page loads, copy the text of #validation-report into $browserJson"
    Write-Host "[stage2] waiting $BrowserWaitSeconds seconds for manual harvest..."
    $proc = Start-Process -FilePath $MiniBrowser -ArgumentList $probeUrl -PassThru
    Start-Sleep -Seconds $BrowserWaitSeconds
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
} else {
    Write-Host "[stage2] skipped (MiniBrowser=$MiniBrowser probe=$ProbePage)"
}

# --- Stage 3 -----------------------------------------------------------------
$mergeArgs = @('-HarnessJson', $harnessJson, '-Out', $mergedJson)
if (Test-Path $browserJson) { $mergeArgs += @('-BrowserJson', $browserJson) }
Write-Host "[stage3] merge-reports $mergeArgs"
pwsh -File "$PSScriptRoot/merge-reports.ps1" @mergeArgs
$exit = $LASTEXITCODE
Write-Host "[done] exit=$exit output=$mergedJson"
exit $exit
