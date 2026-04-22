# Windows WebGPU harness

Standalone Win32 + Dawn program that exercises the exact Dawn/D3D12 call
sequence WebCore will use on Windows, **without** building WebKit. Build
infra is currently blocked; this harness is where Dawn-correctness work lives
until the runner is back.

## Goalposts

Everything in this harness is chosen so a green probe run predicts a green
browser run. The two targets that define "done" for this lane:

1. **[webgpureport.org](https://webgpureport.org/)** — our browser must load
   it, show a non-empty adapter + device panel, and not crash. That requires:
   `navigator.gpu`, `requestAdapter`, `adapter.info`, `adapter.features`,
   `adapter.limits`, `adapter.requestDevice`, `device.features`,
   `device.limits`, `device.queue`. The harness covers all of these through
   `probeAdapterInfo` + `probeDeviceInfo`. See
   [`github.com/webgpu/webgpureport.org`](https://github.com/webgpu/webgpureport.org)
   for the exact fields it reads.
2. **[/webgpu-samples/](https://webgpu.github.io/webgpu-samples/)** — the
   basic samples (helloTriangle, rotatingCube, reversedZ, computeBoids,
   texturedCube, instancedCube, cameras, cornell, …) must run. They all
   exercise the same Dawn call shape the harness tests: shader module →
   render / compute pipeline → command encoder → queue submit →
   (optional) surface present. `probeRenderOffscreen` + `probeComputeSmoke`
   + `probeSurfaceRoundtrip` together cover everything the basic samples
   need below the JS layer.

When a probe fails, it points at a concrete in-tree fix (see
[`docs/INTEGRATION.md`](docs/INTEGRATION.md)).

## Probes

| Probe            | Goalpost coverage                                                                                       |
|------------------|---------------------------------------------------------------------------------------------------------|
| `adapter`        | webgpureport.org adapter panel; every sample's `requestAdapter()`                                       |
| `device`         | webgpureport.org device panel; every sample's `requestDevice()`                                         |
| `buffer`         | samples that use `queue.writeBuffer` + `buffer.mapAsync` readback (computeBoids, imageBlur)             |
| `compute`        | compute-based samples (computeBoids, particles, cornell path tracer)                                    |
| `render`         | basic render samples (helloTriangle, rotatingCube, texturedCube) — offscreen, no HWND needed            |
| `surface`        | anything that presents (all of the above at canvas level); this is the piece in-tree still returns null |
| `errors`         | webgpureport.org's error-surfacing and spec-required `GPUUncapturedErrorEvent`                          |

## CLI

```
webgpu_host.exe [--demo {ball|triangle}] [--no-scene]
                [--probe [--suite <list>] [--json <path>] [--frames N]]
                [--width W] [--height H]
                [--backend {d3d12|d3d11|vulkan|undefined}]
                [--timeout-ms T]
                [--headless]
```

`--suite` takes a comma-separated list: `adapter,device,buffer,compute,render,surface,errors`, or `all`.

Useful combos:

```powershell
# Everything: render the ball + run every probe + write JSON for CI.
webgpu_host.exe --probe --suite all --demo ball --frames 60 --json out.json

# Goalpost 1 check (webgpureport.org coverage): no window, no render.
webgpu_host.exe --probe --suite adapter,device,errors --no-scene --json report.json

# Goalpost 2 check (basic samples coverage): no HWND needed.
webgpu_host.exe --probe --suite buffer,compute,render,errors --no-scene --json samples.json

# Full surface-present path: requires a visible window.
webgpu_host.exe --probe --suite surface,render --demo triangle --frames 8 --json present.json
```

## Report shape

```json
{
  "runtime": {
    "gpuAvailable": true,
    "queueAvailable": true,
    "adapter":  { "backend": "D3D12", "vendor": "...", "device": "..." },
    "surface":  { "configured": true, "format": "BGRA8Unorm" },
    "render":   { "framesSubmitted": 60, "framesPresented": 60, "lastError": null },
    "probes": {
      "adapterInfo":     { "ok": true,  "detail": "ok", "backend": "D3D12", "features": [...], "limits": { ... } },
      "deviceInfo":      { "ok": true,  "detail": "ok", "features": [...], "limits": { ... } },
      "bufferReadback":  { "ok": true,  "detail": "ok (256 u32 roundtrip)", "bytesRoundTripped": 1024, ... },
      "computeSmoke":    { "ok": true,  "detail": "ok (1024 elements)", "elements": 1024, "workgroups": 16 },
      "renderOffscreen": { "ok": true,  "detail": "ok (center pixel green)", "centerPixel": [0,255,0,255] },
      "errorCallback":   { "ok": true,  "detail": "Validation error: ...", "uncapturedFired": true },
      "surfaceRoundtrip":{ "ok": true,  "detail": "ok", "acquiredTexture": true, "acquiredFormat": "BGRA8Unorm" }
    },
    "probesOk": true
  }
}
```

Exit codes: `0` = everything passed. `6` = bootstrap succeeded but at least
one probe failed or render did not present when a scene was requested. `3/4/5`
= earlier bootstrap / surface / scene failures.

## Layout

```
changes/windows-webgpu-service/harness/
  CMakeLists.txt, vcpkg.json, scripts/run.ps1
  docs/
    INTEGRATION.md            per-probe map to WebCore + samples
    PROCESS_ARCHITECTURE.md   Milestone-4 separate-process notes
  include/webgpu_host/
    Host.h        public types
    Probes.h      probe ids and entry points
  src/
    main.cpp, dawn_bootstrap.cpp, surface.cpp, probe.cpp
    scene_bouncing_ball.cpp, scene_triangle.cpp
    probe_adapter_info.cpp, probe_buffer_readback.cpp,
    probe_compute_smoke.cpp, probe_error_callback.cpp,
    probe_surface_roundtrip.cpp, probe_render_offscreen.cpp, probe_suite.cpp
```

## Build

```powershell
pwsh ./changes/windows-webgpu-service/harness/scripts/run.ps1 `
     -Probe -Frames 8 -Json build/webgpu-host/report.json
```

Requires vcpkg with `webgpu-dawn` and `VCPKG_ROOT` set. Manual configure:

```powershell
cmake -S changes/windows-webgpu-service/harness `
      -B build/webgpu-host -G Ninja `
      -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake"
cmake --build build/webgpu-host
```

## Scope rule

Same rule as the rest of the lane: when a probe fails, the fix lives in
`webkit/patches/windows/` or `changes/windows-webgpu-service/patches/windows/`,
not in a hotfix on the builder. The probe output is the evidence that a lane
patch was necessary and that it worked.
