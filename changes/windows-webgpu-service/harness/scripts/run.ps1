[CmdletBinding()]
param(
    [ValidateSet('ball','triangle')]
    [string] $Demo = 'ball',

    [int] $Width = 960,
    [int] $Height = 640,
    [int] $Frames = 0,

    [ValidateSet('d3d12','d3d11','vulkan','undefined')]
    [string] $Backend = 'd3d12',

    [switch] $Probe,
    [string] $Json,
    [string] $BuildDir = 'build/webgpu-host',
    [switch] $Clean,
    [switch] $NoBuild
)

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../..')
$harness  = Resolve-Path (Join-Path $PSScriptRoot '..')
$buildAbs = Join-Path $repoRoot $BuildDir

if ($Clean -and (Test-Path $buildAbs)) {
    Write-Host "[run] cleaning $buildAbs"
    Remove-Item $buildAbs -Recurse -Force
}

if (-not $NoBuild) {
    $toolchain = $null
    if ($env:VCPKG_ROOT) {
        $toolchain = Join-Path $env:VCPKG_ROOT 'scripts/buildsystems/vcpkg.cmake'
    }

    $configArgs = @(
        '-S', $harness,
        '-B', $buildAbs,
        '-G', 'Ninja',
        '-DCMAKE_BUILD_TYPE=Release'
    )
    if ($toolchain -and (Test-Path $toolchain)) {
        $configArgs += "-DCMAKE_TOOLCHAIN_FILE=$toolchain"
        if (-not $env:VCPKG_DEFAULT_TRIPLET) {
            $configArgs += '-DVCPKG_TARGET_TRIPLET=x64-windows'
        }
    }

    Write-Host "[run] cmake $configArgs"
    cmake @configArgs
    if ($LASTEXITCODE -ne 0) { throw "cmake configure failed ($LASTEXITCODE)" }

    cmake --build $buildAbs --config Release
    if ($LASTEXITCODE -ne 0) { throw "cmake build failed ($LASTEXITCODE)" }
}

$exe = Join-Path $buildAbs 'webgpu_host.exe'
if (-not (Test-Path $exe)) {
    $exe = Join-Path $buildAbs 'Release/webgpu_host.exe'
}
if (-not (Test-Path $exe)) {
    throw "webgpu_host.exe not found in $buildAbs"
}

$runArgs = @('--width', $Width, '--height', $Height, '--backend', $Backend)
if ($Probe) {
    $runArgs += '--probe'
    if ($Frames -le 0) { $Frames = 8 }
    $runArgs += @('--frames', $Frames)
    if ($Json) { $runArgs += @('--json', $Json) }
} else {
    $runArgs += @('--demo', $Demo)
    if ($Frames -gt 0) { $runArgs += @('--frames', $Frames) }
}

Write-Host "[run] $exe $runArgs"
& $exe @runArgs
exit $LASTEXITCODE
