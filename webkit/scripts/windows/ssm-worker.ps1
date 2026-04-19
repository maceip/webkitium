#Requires -Version 5.1
# Long-running WebKit build + artifact sync, started detached from the short SSM bootstrap (see build.sh).
param(
  [Parameter(Mandatory = $true)][string]$WorkDir,
  [Parameter(Mandatory = $true)][string]$BundleRoot,
  [Parameter(Mandatory = $true)][string]$S3Prefix,
  [Parameter(Mandatory = $true)][string]$AwsExe
)
$ErrorActionPreference = "Stop"

# Redirect ALL output (stdout+stderr) to a log so we're never blind if the worker dies.
$workerLog = Join-Path $WorkDir "worker-output.log"
Start-Transcript -Path $workerLog -Force -ErrorAction SilentlyContinue

function Write-WorkerJson {
  param([string]$Path, [object]$Object)
  ($Object | ConvertTo-Json -Depth 8 -Compress) | Set-Content -Path $Path -Encoding UTF8
}

function Write-WorkerStatus {
  param([string]$Status, [string]$Stage, [object]$Details = $null)
  Write-WorkerJson -Path (Join-Path $WorkDir "status.json") -Object ([ordered]@{
    schema = 1
    status = $Status
    stage = $Stage
    updated = (Get-Date).ToUniversalTime().ToString("o")
    pid = $PID
    details = $Details
  })
  Write-WorkerJson -Path (Join-Path $WorkDir "heartbeat.json") -Object ([ordered]@{
    schema = 1
    status = $Status
    stage = $Stage
    updated = (Get-Date).ToUniversalTime().ToString("o")
    pid = $PID
  })
}

function Write-ArtifactValidity {
  param([string]$ArtDir, [string]$S3Prefix)
  $required = @("patch-manifest.json", "manifest-pre.json", "manifest-post.json", "validation-report.json")
  $files = [ordered]@{}
  foreach ($name in $required) {
    $files[$name] = Test-Path (Join-Path $ArtDir $name)
  }
  $tarballs = @(Get-ChildItem -Path $ArtDir -Filter "webkitium-windows-*.tar.gz" -ErrorAction SilentlyContinue)
  $files["releaseTarball"] = $tarballs.Count -gt 0
  $valid = -not ($files.Values -contains $false)
  $report = [ordered]@{
    schema = 1
    valid = $valid
    files = $files
    s3Prefix = $S3Prefix
    updated = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-WorkerJson -Path (Join-Path $WorkDir "artifact-validity.json") -Object $report
  if (-not $valid) {
    throw "artifact validity failed: required files missing; see artifact-validity.json"
  }
}

try {
  Set-Location $WorkDir
  Write-WorkerStatus -Status "running" -Stage "worker-start"
  # Tar extract is often MOTW-blocked; without Unblock-File, & remote-build.ps1 may not run.
  Get-ChildItem -Path $BundleRoot -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
  Write-Output "worker: Unblock-File done, invoking remote-build.ps1"
  if (Test-Path (Join-Path $WorkDir "CANCEL_REQUESTED.txt")) {
    "cancelled before remote-build start $((Get-Date).ToUniversalTime().ToString('o'))" | Set-Content -Path (Join-Path $WorkDir "BUILD_CANCELLED.txt") -Encoding UTF8
    Write-WorkerStatus -Status "cancelled" -Stage "worker-start"
    return
  }
  Write-WorkerStatus -Status "running" -Stage "remote-build"
  & (Join-Path $BundleRoot "remote-build.ps1")
  if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "remote-build.ps1 exited with code $LASTEXITCODE"
  }
  "remote-build complete $((Get-Date).ToUniversalTime().ToString('o'))" |
    Set-Content -Path (Join-Path $WorkDir "BUILD_READY.txt") -Encoding UTF8
  $art = Join-Path $WorkDir "artifacts"
  if (Test-Path $art) {
    Write-WorkerStatus -Status "running" -Stage "artifact-validate"
    Write-ArtifactValidity -ArtDir $art -S3Prefix $S3Prefix
    Copy-Item (Join-Path $WorkDir "artifact-validity.json") $art -Force
    Copy-Item (Join-Path $WorkDir "status.json") $art -Force
    Copy-Item (Join-Path $WorkDir "heartbeat.json") $art -Force
    Copy-Item (Join-Path $WorkDir "cache-state.json") $art -Force -ErrorAction SilentlyContinue
    Write-WorkerStatus -Status "running" -Stage "artifact-upload"
    Write-Output "worker: syncing artifacts to $S3Prefix"
    & $AwsExe s3 sync $art $S3Prefix --exclude "*" --include "*.zip" --include "*.tar.gz" --include "*.json" --include "*.log" --include "*.html"
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
      throw "aws s3 sync exited with code $LASTEXITCODE"
    }
  }
  $done = Join-Path $WorkDir "BUILD_DONE.txt"
  Write-WorkerStatus -Status "succeeded" -Stage "done" -Details @{ s3Prefix = $S3Prefix }
  "success $((Get-Date).ToUniversalTime().ToString('o')) uploaded=$S3Prefix" | Set-Content -Path $done -Encoding UTF8
} catch {
  $err = $_ | Out-String
  Write-Output "worker: CAUGHT ERROR: $err"
  if (Test-Path (Join-Path $WorkDir "BUILD_CANCELLED.txt")) {
    Write-WorkerStatus -Status "cancelled" -Stage "cancelled" -Details @{ error = $err }
  } else {
    Write-WorkerStatus -Status "failed" -Stage "failed" -Details @{ error = $err }
  }
  $art = Join-Path $WorkDir "artifacts"
  if (Test-Path $art) {
    try {
      Write-Output "worker: syncing failure artifacts to $S3Prefix"
      & $AwsExe s3 sync $art $S3Prefix --exclude "*" --include "*.zip" --include "*.tar.gz" --include "*.json" --include "*.log" --include "*.html"
    } catch {
      Write-Output "worker: failure artifact sync also failed: $($_ | Out-String)"
    }
  }
  try {
    if (Test-Path (Join-Path $WorkDir "BUILD_CANCELLED.txt")) {
      $err | Add-Content (Join-Path $WorkDir "BUILD_CANCELLED.txt") -Encoding UTF8
    } else {
      $err | Set-Content (Join-Path $WorkDir "BUILD_FAILED.txt") -Encoding UTF8
    }
  } catch {
    # Last resort: if even writing the marker fails, at least the transcript has the error.
  }
} finally {
  # Guarantee a marker exists: if neither DONE nor FAILED was written, write FAILED with what we know.
  $doneFile = Join-Path $WorkDir "BUILD_DONE.txt"
  $failFile = Join-Path $WorkDir "BUILD_FAILED.txt"
  if (-not (Test-Path $doneFile) -and -not (Test-Path $failFile)) {
    try {
      if (Test-Path (Join-Path $WorkDir "BUILD_CANCELLED.txt")) {
        Write-WorkerStatus -Status "cancelled" -Stage "finally"
      } else {
        "worker exited without markers at $((Get-Date).ToUniversalTime().ToString('o')) - see worker-output.log" |
          Set-Content -Path $failFile -Encoding UTF8
        Write-WorkerStatus -Status "failed" -Stage "finally"
      }
    } catch {}
  }
  Stop-Transcript -ErrorAction SilentlyContinue
}
