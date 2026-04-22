# Harness ↔ WebCore ↔ goalposts mapping

Every probe ties to:
1. A specific file under `Source/WebCore/Modules/WebGPU/Implementation` (or
   `Source/WebCore/Modules/WebGPU`) that needs to work for the probe to pass
   inside a built browser.
2. A specific section of [webgpureport.org](https://github.com/webgpu/webgpureport.org)
   or a specific [/webgpu-samples/](https://github.com/webgpu/webgpu-samples)
   entry that will light up when the probe passes.

If a probe passes standalone but fails in the browser, the issue is
WebCore-side translation. If a probe fails standalone, the issue is below
WebCore (Dawn pin, D3D12 driver, or an in-tree Dawn-facing patch is
missing / wrong).

## Bootstrap (implicit probe)

| Harness | WebCore | webgpureport | samples |
|--|--|--|--|
| `src/dawn_bootstrap.cpp` → `wgpuCreateInstance`, `wgpuInstanceRequestAdapter`, `wgpuAdapterRequestDevice` with `wgpuInstanceProcessEvents` pumping | `Modules/WebGPU/Implementation/WebGPUImpl.cpp` (`GPUImpl::requestAdapter`), `WebGPUAdapterImpl.cpp` (`AdapterImpl::requestDevice`) | "Adapter" section top-line + "Device" top-line | Every sample's first ~10 lines (`navigator.gpu.requestAdapter()` + `adapter.requestDevice()`) |

In-tree patches that already set this up: `0001-windows-dawn-request-adapter-runtime`,
`0014-windows-webgpu-request-device-default-descriptor`, `0021` (relaxation,
WebKit-ng only, worth upstreaming if the D3D12 path rejects explicit backend).

## `probeAdapterInfo`

| Goalpost fields | Source |
|--|--|
| adapter panel: vendor, architecture, device, description, backend, adapter type, vendor/device IDs | `wgpuAdapterGetInfo` |
| feature chips | `wgpuAdapterGetFeatures` |
| limits table | `wgpuAdapterGetLimits` |

WebCore call path (must be correct for this to reach JS):
- `Modules/WebGPU/GPUAdapter.cpp` → `GPUAdapter::info()`, `::features()`, `::limits()`
- `Modules/WebGPU/GPUAdapterInfo.cpp` (carries `vendor`, `architecture`, `device`, `description`)
- `Modules/WebGPU/GPUSupportedFeatures.cpp`, `GPUSupportedLimits.cpp`

If the probe shows `vendor: "Microsoft"`, `device: "Microsoft Basic Render
Driver"` on a machine that has a real GPU, the Dawn pin or adapter power
preference is wrong — revisit `0021`.

## `probeDeviceInfo`

| Goalpost | Source |
|--|--|
| device panel limits + features; "Device is valid" badge | `wgpuDeviceGetLimits`, `wgpuDeviceGetFeatures`, `wgpuDeviceGetQueue` |

WebCore:
- `Modules/WebGPU/GPUDevice.cpp`
- `Modules/WebGPU/Implementation/WebGPUDeviceImpl.cpp`

## `probeBufferReadback`

| Goalpost | Source |
|--|--|
| samples/computeBoids, samples/imageBlur — any `mapAsync` usage | `wgpuQueueWriteBuffer`, `wgpuCommandEncoderCopyBufferToBuffer`, `wgpuBufferMapAsync`, `wgpuBufferGetConstMappedRange`, `wgpuBufferUnmap` |

WebCore:
- `Modules/WebGPU/Implementation/WebGPUQueueImpl.cpp` (`writeBuffer` — fixed on Windows by `0015-windows-dawn-compute-smoke-core`)
- `Modules/WebGPU/Implementation/WebGPUBufferImpl.cpp` (`mapAsync`, `getMappedRange`)
- `Implementation/WebGPU/WebGPUExt.h` (`wgpuBufferGetInitialSize` — fixed by `0017-windows-dawn-buffer-size-readback`)

## `probeComputeSmoke`

| Goalpost | Source |
|--|--|
| samples/computeBoids, samples/particles (compute paths), webgpureport compute smoke | WGSL → `wgpuDeviceCreateShaderModule`, `wgpuDeviceCreateComputePipeline`, `wgpuCommandEncoderBeginComputePass`, `wgpuComputePassEncoderDispatchWorkgroups` |

WebCore:
- `Implementation/WebGPUDeviceImpl.cpp` — `createShaderModule`, `createComputePipeline` (enabled on Windows by `0015-0019`)
- `Implementation/WebGPUCommandEncoderImpl.cpp` — `beginComputePass` (ditto)

## `probeRenderOffscreen`

| Goalpost | Source |
|--|--|
| samples/helloTriangle, rotatingCube, texturedCube, cameras, reversedZ | `wgpuDeviceCreateRenderPipeline` with vertex buffer layout, `wgpuCommandEncoderBeginRenderPass` + `setPipeline` / `setVertexBuffer` / `draw`, `wgpuCommandEncoderCopyTextureToBuffer` |

WebCore:
- `Implementation/WebGPUDeviceImpl.cpp` — `createRenderPipeline`
- `Implementation/WebGPURenderPassEncoderImpl.cpp` — `setPipeline`, `setVertexBuffer`, `draw`
- `Implementation/WebGPUCommandEncoderImpl.cpp` — `copyTextureToBuffer`

This is the last Dawn entry-point family not yet exhaustively covered by a
Windows patch series. If this probe fails but `probeComputeSmoke` passes, the
next patch is likely a Windows-side tweak to `WebGPURenderPipelineImpl.cpp`
(auto layout / depth-stencil defaults).

## `probeSurfaceRoundtrip`

| Goalpost | Source |
|--|--|
| Every canvas-rendered sample — this is the blocker today | `wgpuInstanceCreateSurface` with `WGPUSurfaceDescriptorFromWindowsHWND`, `wgpuSurfaceConfigure`, `wgpuSurfaceGetCapabilities`, `wgpuSurfaceGetCurrentTexture`, `wgpuTextureGetFormat`, `wgpuSurfacePresent` |

WebCore work still required:
- `Modules/WebGPU/GPUCanvasContext.cpp` returns `nullptr` on non-Cocoa — needs a `GPUCanvasContextWin` that wires the HWND through.
- `Implementation/WebGPUImpl.cpp::createPresentationContext` currently builds a Cocoa descriptor — needs a `#if PLATFORM(WIN)` branch using `WGPUSurfaceDescriptorFromWindowsHWND` (shape already in `src/surface.cpp`).
- `Implementation/WebGPU/WebGPUExt.h` has stub `wgpuDeviceCreateSwapChain` / `wgpuSwapChainGetCurrentTexture` / `wgpuSwapChainPresent` — the real path is the `wgpuSurface*` family; either re-plumb WebCore callers or turn the stubs into inline adapters.

## `probeErrorCallback`

| Goalpost | Source |
|--|--|
| webgpureport.org error panel, `GPUUncapturedErrorEvent` spec compliance | `WGPUUncapturedErrorCallbackInfo`, `wgpuDevicePushErrorScope` / `wgpuDevicePopErrorScope` |

WebCore:
- `Modules/WebGPU/GPUDevice.cpp` — `onuncapturederror` event
- `Implementation/WebGPUDeviceImpl.cpp` — where the uncaptured error callback is installed

Without this, pages silently swallow validation errors — webgpureport.org
flags a warning and many samples misbehave in surprising ways.

## After a probe fails

The expected flow:

1. Probe fails in the harness → you now know Dawn on this host does X.
2. Write or update a patch under `webkit/patches/windows/` or
   `changes/windows-webgpu-service/patches/windows/` that teaches WebCore the
   correct shape.
3. Update this file's "Mapped WebCore files" row for that probe so the next
   person sees the loop closed.
4. Land the patch; when builds come back, re-run the harness + MiniBrowser
   probe and verify both goalposts.
