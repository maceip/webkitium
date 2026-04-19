#Requires -Version 5.1
param(
  [Parameter(Mandatory = $true)][string]$WorkDir,
  [Parameter(Mandatory = $true)][string]$BundleRoot,
  [Parameter(Mandatory = $true)][string]$S3Prefix,
  [Parameter(Mandatory = $true)][string]$AwsExe
)
$ErrorActionPreference = "Stop"

Set-Location $WorkDir
Get-ChildItem -Path $BundleRoot -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

$worker = Join-Path $BundleRoot "worker-control.py"
if (-not (Test-Path $worker)) {
  throw "worker-control.py missing in bundle at $worker"
}

$pythonCandidates = @(
  "C:\Python314\python.exe",
  "C:\Python313\python.exe",
  "C:\Python312\python.exe",
  "python.exe",
  "py.exe"
)
$python = $null
foreach ($candidate in $pythonCandidates) {
  $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
  if ($cmd) {
    $python = $cmd.Source
    break
  }
}
if (-not $python) {
  throw "Python not found for worker-control.py"
}

& $python $worker `
  --platform windows `
  --workdir $WorkDir `
  --bundle-root $BundleRoot `
  --s3-prefix $S3Prefix `
  --aws-exe $AwsExe
exit $LASTEXITCODE
