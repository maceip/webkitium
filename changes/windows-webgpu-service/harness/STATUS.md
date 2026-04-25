# Windows WebGPU lane — status & open question

## Compile pipeline: green

- `windows-build` workflow produces a working WebKit on the self-hosted runner.
- 50/50 patches apply cleanly to the pinned WebKit (`1f41867`).
- Pinned Dawn (`google/dawn v20260410.140140` via vcpkg baseline `17e4940625`) compiled with D3D12 + D3D11 + Vulkan backends; `webgpu_dawn.dll` ships next to MiniBrowser, plus DXC (`dxil.dll` + `dxcompiler.dll`).
- All 5 cross-platform release lanes (Windows/macOS/iOS/Linux/Android) are green.

## Standalone Dawn: works

`changes/windows-webgpu-service/harness/webgpu_host.exe` runs all six probes against the pinned Dawn and returns a full JSON report on the laptop's real GPU (Intel Arc 140V):

```
adapter:        D3D12, intel, "Intel(R) Arc(TM) 140V GPU (16GB)"
queueAvailable: true
adapterInfo:    ok
deviceInfo:     ok
bufferReadback: ok (256 u32 roundtrip)
computeSmoke:   ok (1024 elements)
errorCallback:  ok
renderOffscreen:ok (center pixel green)
probesOk:       true
```

This proves Dawn-on-Windows + DXC + the WebGPU API surface our patches target are all healthy.

## MiniBrowser → WebKit: blocked

JS calls `navigator.gpu.requestAdapter()` successfully, then `adapter.requestDevice()` synchronously crashes WebKitWebProcess:

```
Exception:    C0000005 ACCESS_VIOLATION
Crash IP:     WebCore::GPUAdapter::info+0x4
Instruction:  inc dword ptr [rcx]    (Ref<>::ref())
rcx:          0xffffffeeffffffeb     (WebKit Ref<> poisoned-pointer signature)
```

The poison value is the textbook tell that we are dereferencing a `Ref<GPUAdapterInfo>` whose underlying object has already been destroyed. The dump's caller frame return address is in JavaScriptCore.dll, so the call to `info()` is being driven by a JSC binding.

## Why my patches haven't moved the crash

WebKit2 on Windows uses **multi-process WebGPU**:

- WebProcess holds `RemoteAdapterProxy` (in WebKit2.dll). When JS calls `requestDevice`, that proxy IPCs the request to GPUProcess.
- GPUProcess holds `RemoteAdapter` and the platform implementation `WebCore::WebGPU::AdapterImpl` (in WebCore.dll).
- **Our patches (0005, 0014, 0033, 0034, 0044) all modify `AdapterImpl` — which only runs in GPUProcess.** They are correct for the GPU-side, but they are downstream of the crash.

Confirmation: I added a file-write trace (`fopen("%TEMP%\\webgpu-debug.log", "a")`) at every step of `AdapterImpl::requestDevice` and `dawnRequestDeviceCallback`. The strings made it into `WebCore.dll` (4× `AdapterImpl::requestDevice`, 7× `dawnRequestDeviceCallback`) but the log file is never created. Procdump on WebKitGPUProcess shows it sitting fully idle while WebKitWebProcess crashes — meaning the IPC for `requestDevice` never makes it across.

The crash is somewhere in the **WebProcess-side** chain:
- `JSGPUAdapter::requestDevice` (generated binding)
- `WebCore::GPUAdapter::requestDevice` (`Source/WebCore/Modules/WebGPU/GPUAdapter.cpp`)
- `RemoteAdapterProxy::requestDevice` (`Source/WebKit/WebProcess/GPU/graphics/WebGPU/RemoteAdapterProxy.cpp`)
- The captured-`protectedThis` lambda inside `GPUAdapter::requestDevice`.

`GPUAdapter::requestDevice` builds a lambda that captures `protectedThis = protect(*this)` and `deviceDescriptor` by value, then waits on `m_backing->requestDevice(...)`. On Windows the lambda is invoked with the IPC reply. Patch 0014 fixes one nullopt deref in that lambda; the remaining crash signature suggests either:

1. Another lifetime issue in `GPUAdapter`'s `m_info` / `m_backing` interaction during the lambda's `protectedThis->name()` call, or
2. A `RemoteAdapterProxy` vtable / layout mismatch on Windows that makes a `Ref<GPUAdapter>` reference appear poisoned.

## Concrete next steps

In order of cost:

1. **Patch the WebProcess-side spec layer.** Add a small Windows-only patch to `Source/WebCore/Modules/WebGPU/GPUAdapter.cpp` that defensively copies `m_info` into the lambda capture instead of going through `protectedThis->name()` after the synchronous IPC returns. If the lambda's call into `protectedThis` is hitting a freed object, copying out the few fields we actually need before the IPC sidesteps the issue.
2. **Bypass GPUProcess for WebGPU on Windows.** Add a runtime feature `UseGPUProcessForWebGPUEnabled` (it doesn't exist in WebKit yet) and route `WebGPUEnabled` straight into in-process `GPUImpl`. This is a bigger patch but produces the full Dawn-in-WebProcess path our patches were built for.
3. **Capture the WebProcess crash with line-level symbols.** WinDbg-with-PDB on the latest dump and step from `requestDevice+0x?` back to source. The cdb session in the previous round hit an LTO-folded code path; full source-line resolution needs a non-LTO build, which costs one CI build.

The lowest-risk single move is (1): a focused, ≤50-line patch that pre-copies the data the lambda needs and avoids touching `protectedThis` in the IPC reply. If that lands the device, all of (0005, 0014, 0033, 0034, 0044) are in fact correct and we go straight to runtime exercise of `setHostHWND` (0042), `computeSmoke`, and the canvas-render path.

## Reproducer drop

`webkitium-webgpu-laptop.zip` at the repo root contains everything needed to reproduce locally:

- `bin/MiniBrowser.exe` + WebKit DLLs + `webgpu_dawn.dll` + DXC
- `bin/webgpu_host.exe` (standalone Dawn proof)
- `validate-probe.html` + `browser-probe-server.py`
- `run-probe.ps1` (full WebKit path) and `run-standalone.ps1` (Dawn-only)
- Procdump-ready (HKCU LocalDumps preconfigured for `WebKitWebProcess.exe`).

The same JSON report shape is captured from both lanes so the WebKit failure can be diff'd against the standalone success.
