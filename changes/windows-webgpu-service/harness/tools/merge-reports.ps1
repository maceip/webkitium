# Merge the standalone harness JSON report and the in-browser probe JSON
# (harvested from MiniBrowser's validate-probe.html) into one
# validation-report.json matching the shape the runner docs describe.
#
# Inputs (any can be omitted; missing data is simply absent from the output):
#   -HarnessJson  path to webgpu_host.exe --probe --json output
#   -BrowserJson  path to the JSON scraped from document.getElementById('validation-report')
#   -Out          path to write the merged report (default: validation-report.json)
#
# The merge rules:
#   - Scalar fields prefer browser values (they reflect what the user sees)
#     and fall back to harness values. This keeps the runner's single-source
#     expectation intact.
#   - `probes` is a union keyed by probe name. Harness probes are prefixed
#     `harness.<name>`; browser probes keep their bare name. That way the
#     two families are always distinguishable even when they overlap.
#   - `overallOk` is the AND of every `.ok` flag across both families.
#
# When the runner returns, it can call this script as-is, or import the
# same rules natively — the shape is stable.

[CmdletBinding()]
param(
    [string] $HarnessJson,
    [string] $BrowserJson,
    [string] $Out = "validation-report.json"
)

$ErrorActionPreference = 'Stop'

function Read-JsonFile {
    param([string] $Path)
    if (-not $Path)          { return $null }
    if (-not (Test-Path $Path)) { return $null }
    $text = Get-Content -Raw $Path
    if (-not $text) { return $null }
    return $text | ConvertFrom-Json -Depth 32
}

$harness = Read-JsonFile $HarnessJson
$browser = Read-JsonFile $BrowserJson

$merged = [ordered]@{
    runtime = [ordered]@{
        gpuAvailable      = $false
        queueAvailable    = $false
        adapter           = $null
        surface           = [ordered]@{ configured = $false; format = $null }
        render            = [ordered]@{ framesSubmitted = 0; framesPresented = 0; lastError = $null }
        probes            = [ordered]@{}
        overallOk         = $true
        sources           = [ordered]@{
            harness = $HarnessJson
            browser = $BrowserJson
        }
    }
}

function Copy-IfPresent {
    param($src, $dst, [string] $path)
    $parts = $path -split '\.'
    $s = $src
    foreach ($p in $parts) {
        if ($null -eq $s) { return $null }
        $s = $s.$p
    }
    return $s
}

function Merge-Runtime {
    param($src)
    if ($null -eq $src) { return }
    if ($src.PSObject.Properties.Name -notcontains 'runtime') { return }
    $r = $src.runtime
    if ($null -ne $r.gpuAvailable)   { $merged.runtime.gpuAvailable   = [bool]$r.gpuAvailable }
    if ($null -ne $r.queueAvailable) { $merged.runtime.queueAvailable = [bool]$r.queueAvailable }
    if ($null -ne $r.adapter)        { $merged.runtime.adapter        = $r.adapter }
    if ($null -ne $r.surface) {
        if ($null -ne $r.surface.configured) { $merged.runtime.surface.configured = [bool]$r.surface.configured }
        if ($null -ne $r.surface.format)     { $merged.runtime.surface.format     = [string]$r.surface.format }
    }
    if ($null -ne $r.render) {
        if ($null -ne $r.render.framesSubmitted) { $merged.runtime.render.framesSubmitted += [int]$r.render.framesSubmitted }
        if ($null -ne $r.render.framesPresented) { $merged.runtime.render.framesPresented += [int]$r.render.framesPresented }
        if ($null -ne $r.render.lastError)       { $merged.runtime.render.lastError       = [string]$r.render.lastError }
    }
}

Merge-Runtime $harness
Merge-Runtime $browser

# Probes. Harness results go under harness.<name>; browser keeps bare names.
function Merge-Probes {
    param($src, [string] $prefix)
    $probes = Copy-IfPresent $src $null 'runtime.probes'
    if ($null -eq $probes) { return }
    foreach ($name in $probes.PSObject.Properties.Name) {
        $p = $probes.$name
        $key = if ($prefix) { "$prefix.$name" } else { $name }
        $merged.runtime.probes[$key] = $p
        if ($null -ne $p.ok -and -not $p.ok) { $merged.runtime.overallOk = $false }
    }
}

Merge-Probes $harness 'harness'
Merge-Probes $browser $null

# Roll bootstrap success into overallOk.
if (-not $merged.runtime.gpuAvailable)   { $merged.runtime.overallOk = $false }
if (-not $merged.runtime.queueAvailable) { $merged.runtime.overallOk = $false }

$json = $merged | ConvertTo-Json -Depth 32
[System.IO.File]::WriteAllText((Resolve-Path -LiteralPath (Split-Path -Parent $Out)).Path + [System.IO.Path]::DirectorySeparatorChar + (Split-Path -Leaf $Out), $json)

Write-Host "[merge] wrote $Out (overallOk=$($merged.runtime.overallOk), probes=$($merged.runtime.probes.Count))"
exit ($merged.runtime.overallOk ? 0 : 6)
