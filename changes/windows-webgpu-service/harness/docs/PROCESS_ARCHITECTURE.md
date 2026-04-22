# Separate-process WebGPU — design and path forward

This memo records the decisions for Milestone 4 of the Windows WebGPU lane
(see `docs/WEBGPU_PROGRAM.md`). It is intentionally short; the current harness
does not need any of this to show the bouncing ball.

## Today's picture

- **In-tree multi-process.** Apple's `Source/WebKit/GPUProcess/graphics/WebGPU/`
  implements a Cocoa-centric GPU-process path (`RemoteGPU`, `RemoteAdapter`,
  `RemoteDevice`, IOSurface-backed framebuffers, Mach IPC). It is **not the
  path we use on Windows.** Patches `0009`–`0011` in the lane *gate off* its
  Model/Mesh and IOSurface pieces on Windows so the build compiles.
- **In-process Dawn.** Windows runs Dawn + D3D12 inside the WebContent process
  via `Source/WebCore/Modules/WebGPU/Implementation/`. This is deliberate
  (see `docs/WEBGPU_PROGRAM.md § strategy` point 1): ship the canvas + rAF
  loop first, don't require GPU-process parity.
- **No separate WebGPU host process** exists yet. The name
  `windows-webgpu-service` is a **change lane**, not a running service.

## Why move to a separate process eventually

Only when policy requires it:

- sandboxing the GPU process away from JS/DOM,
- surviving Dawn/D3D12 crashes without killing the tab,
- sharing a single Dawn instance across multiple WebContent processes,
- enabling kernel-side graphics sandboxing without giving the content
  process a GPU device handle.

None of those are prerequisites for "ball bouncing on the screen." They are
the Milestone 4 trigger.

## What the separate process looks like

A second copy of **this harness binary**, launched with `--serve`, driven by
IPC from WebCore instead of a local `Scene`. Concretely:

```
WebContent (process A)                          GPUHost.exe (process B)
  navigator.gpu  ──▶  RemoteGPU_Windows  ────▶  dispatch
  canvas.ctx     ──▶  (send cmds over pipe)      ├── Dawn instance / adapter / device
  rAF tick       ──▶                             ├── surface tied to DWM composition
                                                 └── per-frame tick
```

**Transport.** Windows-native named pipes (`\\.\pipe\webgpu-host-<pid>`) or
an anonymous duplex pipe inherited from the parent. We do **not** use Mach
IPC (Cocoa-only) and we **do not** need Dawn Wire for a single-client
topology — a hand-written command protocol on a pipe is easier to debug.

**Surface.** The tab's `HWND` (or a child HWND owned by the compositor) is
sent to the host as a `HANDLE` via `DuplicateHandle` or as an HWND integer
(both processes are in the same desktop session, so HWNDs are shared).
`surface.cpp` uses the same `WGPUSurfaceDescriptorFromWindowsHWND` path
either way.

**Message shape.** The command set is a subset of `WebCore::WebGPU::*` method
calls, serialized:

```
enum class Cmd : uint32_t {
    Hello = 1,               // handshake, report backend + limits
    AttachSurface,           // HWND + HINSTANCE + initial size
    ConfigureSurface,        // width, height, format, usage, presentMode
    CreateBuffer,            // id, usage, size
    CreateShaderModule,      // id, wgsl
    CreatePipeline,          // id, serialized descriptor
    CreateBindGroup,         // id, entries
    BeginFrame,              // dtSeconds
    Submit,                  // serialized command list (one render pass)
    Present,                 //
    Shutdown,
};
```

Each `CreateX` allocates a server-side ID that the client uses in subsequent
commands. No command references a raw pointer; resources are handle-based
(matches WebGPU's own model).

## What to build next (in order)

1. **Land the harness** as the standalone lane validator (this directory).
   That already takes WebGPU-on-Windows out of the "needs a 76-minute WebKit
   build to iterate" hole.
2. **Add `--serve` mode to the harness** reading the command enum above from
   stdin / a pipe, dispatching to the exact same Dawn wrappers used by
   `Scene`. A small test client in the same binary drives it with scripted
   commands (no real WebKit required).
3. **Define `RemoteGPU_Windows`** in a new patch under
   `changes/windows-webgpu-service/patches/windows/`. That patch:
   - introduces a `GPUConnectionToWebGPUHost` class in WebKit's WebContent,
   - wires `Navigator::gpu()` on Windows to return a proxy that forwards
     requestAdapter/requestDevice/canvas calls across the pipe,
   - keeps Apple's `RemoteGPU` untouched (still disabled on Windows).
4. **Milestone-4 gate.** Promote the harness probe report to include the
   bounce scene submitted and presented over IPC, not locally.

Until step 3, the harness + in-process Dawn (current strategy) is the
shippable path.

## Non-goals

- Dawn Wire. If we ever need cross-machine or cross-API serialization, it
  can land later. For a single local WebContent ↔ single local GPUHost, it
  is more machinery than the problem requires.
- Resurrecting the deleted `platform/graphics/gpu/dawn` sources. `USE_DAWN`
  is a dead switch (see `DESIGN.md`).
- Touching the Cocoa `GPUProcess` beyond gating — that stays
  Cocoa-specific.
