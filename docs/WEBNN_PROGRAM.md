# WebNN Program (WebKit NG — all platforms)

WebKit NG ships on **Android, iOS, macOS, and Windows**; this file is the
prescriptive **strategy, milestones, and integration plan** for the **WebNN**
track. For the whole browser and repo shape, see
[`README.md`](../README.md) and [`ARCHITECTURE.md`](ARCHITECTURE.md). For
the pairwise WebGPU program, see [`WEBGPU_PROGRAM.md`](WEBGPU_PROGRAM.md).

**Not here:** S3 layout, build law, runner APIs, patch lists, verification
detail — those stay in the linked files.

---

## Where the rest lives

| Topic | File |
|-------|------|
| Repo overview | [`README.md`](../README.md) |
| WebGPU milestones | [`WEBGPU_PROGRAM.md`](WEBGPU_PROGRAM.md) |
| WebNN lane scope & design | [`../changes/webnn-service/README.md`](../changes/webnn-service/README.md) |
| WebNN runtime design | [`../changes/webnn-service/DESIGN.md`](../changes/webnn-service/DESIGN.md) |
| Platform adapters | [`../browser/platform/README.md`](../browser/platform/README.md) |
| Architecture | [`ARCHITECTURE.md`](ARCHITECTURE.md) |

---

## Background

### What is WebNN?

The [Web Neural Network API](https://webmachinelearning.github.io/webnn/)
(W3C Candidate Recommendation, January 2026) is a dedicated **low-level API
for neural-network inference hardware acceleration**. It exposes ~95
operations (`conv2d`, `matmul`, `relu`, `softmax`, `gelu`, `lstm`, …) through
a graph-construction → compile → dispatch model backed by OS-level inference
runtimes:

| Platform | CPU backend | GPU backend | NPU backend |
|----------|------------|------------|-------------|
| Windows 11 24H2+ | ONNX Runtime / Windows ML | ONNX Runtime GPU EP | ONNX Runtime NPU EP |
| Windows (default) | TFLite + XNNPACK | DirectML (flag) | DirectML (if hw) |
| macOS Apple Silicon ≥14.4 | Core ML (CPUOnly) | Core ML (CPUAndGPU) | Core ML (NeuralEngine) |
| macOS Intel / <14.4 | TFLite + XNNPACK | TFLite (fallback) | — |
| Linux | TFLite + XNNPACK | CPU fallback | — |
| Android | TFLite + XNNPACK | TFLite OpenCL | TFLite NNAPI |
| ChromeOS | TFLite + XNNPACK | Chrome ML GPU | CPU fallback |

Key design points:
- **Privacy-preserving**: all computation on-device.
- **Hardware-agnostic**: GPUs, CPUs, and dedicated ML accelerators via OS
  backends.
- **WebGPU interop**: `MLTensor.exportToGPU` for zero-copy sharing.
- **Permissions-gated**: `"webnn"` policy, disabled in cross-origin iframes
  by default.

### Relationship to WebGPU

WebNN and WebGPU are **complementary**, not competing:

| Concern | WebGPU | WebNN |
|---------|--------|-------|
| Primary workload | Graphics rendering + general compute shaders | Neural-network inference |
| Programming model | Write WGSL shaders, manage buffers/pipelines | Declare a computation graph, dispatch |
| Hardware target | GPU (D3D12, Vulkan, Metal) | GPU, CPU, or NPU via OS ML runtime |
| Interop | `GPUBuffer`, `GPUTexture` | `MLTensor` can export to `GPUBuffer` |

A typical real-world pipeline: capture frame → WebNN inference (object
detection / segmentation) → WebGPU render (overlay / post-process). Our
browser must support both.

---

## Strategy

### Approach evaluation

Three integration approaches were evaluated:

#### 1. Direct WebNN API (native `navigator.ml`)

WebKit upstream tracks the spec. Chromium already ships `navigator.ml` from
M112+. For our downstream WebKit, this means patching WebCore to wire
`navigator.ml` through to a platform ML backend, mirroring how WebGPU was
wired to Dawn.

**Pros:** Smallest API surface. Standards-only. No JS framework dependency.
Tightest integration with the engine.

**Cons:** Requires per-platform backend implementation (ONNX Runtime on
Windows, Core ML on macOS, TFLite on Linux/Android). Significant C++ work per
platform.

#### 2. Bolt-on ONNX Runtime Web (`onnxruntime-web`)

ONNX Runtime Web is the **most mature** WebNN consumer. Install
`onnxruntime-web`, import the `/all` bundle, set
`executionProviders: [{ name: 'webnn' }]`. Unsupported ops auto-fall back to
WASM. Microsoft co-develops the WebNN spec and this EP.

**Pros:** Production-ready. Runs `.onnx` models. Automatic WASM fallback for
unsupported ops. IO binding with `MLTensor` for zero-copy. Best operator
coverage.

**Cons:** Requires the browser to expose `navigator.ml` first (circular if
WebNN is not wired). Adds a JS-layer dependency. NPM / bundler story needed.

#### 3. Bolt-on LiteRT.js (`@litertjs/core`)

Google's LiteRT.js (v2.4.0) supports WebGPU and CPU today. WebNN support is
**"coming soon"** — active GitHub work exists but no public API surface yet.
Chromium itself already uses TFLite as a WebNN backend internally.

**Pros:** Familiar TFLite model format. Google-backed. Chromium already uses
TFLite underneath WebNN.

**Cons:** **WebNN delegate not yet shipped** in the JS API. Only WebGPU and
CPU available today. Cannot be used as a WebNN consumer until Google ships the
delegate.

### Decision

**Phased approach — all three, in order of readiness:**

1. **Phase A (now):** Wire the **direct WebNN API** into downstream WebKit,
   mirroring the WebGPU/Dawn pattern. Platform backends: ONNX Runtime
   (Windows), Core ML (macOS), TFLite (Linux/Android). This is the engine
   prerequisite — without `navigator.ml`, neither framework can use WebNN.

2. **Phase B (after navigator.ml works):** Integrate **ONNX Runtime Web** as
   the reference JS-level ML framework. Validates WebNN end-to-end with real
   `.onnx` models and proves the WASM fallback path.

3. **Phase C (when available):** Add **LiteRT.js** WebNN delegate support when
   Google ships it. Monitor `@litertjs/core` releases. This gives `.tflite`
   model consumers the same hardware acceleration path.

This phased approach ensures we:
- Unblock the standards-track API first (like we did with WebGPU/Dawn).
- Have a working validation framework (ONNX Runtime Web) before we need
  custom test infrastructure.
- Stay ready for LiteRT.js when Google ships the delegate.

---

## WebNN on Windows — strategy (Phase A lead platform)

1. **Wire ONNX Runtime as the ML backend** through downstream WebKit. ONNX
   Runtime is Microsoft's chosen platform inference engine and already ships
   with Windows 11 24H2+. Use `ENABLE_WEBNN=ON` + `FindONNXRuntime.cmake`.
2. **Do not** require full op coverage to ship. The first milestone is
   `navigator.ml.createContext()` → `MLGraphBuilder` → `builder.build()` →
   `context.dispatch()`.
3. **Coordinate** through the runner: preset `webnn-onnxrt`.

### Product bar

`navigator.ml`, context, graph builder, compiled graph, dispatch, read —
end-to-end inference on a small model (e.g. MobileNet classification or a
simple math graph). NPU and full op coverage are **not** required for first
bar.

### Milestones

| # | Milestone | Exit (must all be true) |
|---|-----------|-------------------------|
| **1** | Foundations | `ENABLE_WEBNN=ON` in cache; ONNX Runtime libs loadable beside MiniBrowser; `navigator.ml` exists in JS. |
| **2** | Context + graph build | `navigator.ml.createContext({devicePreference:'cpu'})` succeeds; `MLGraphBuilder` constructs a simple add/mul graph; `builder.build()` compiles. |
| **3** | Dispatch + readback | `context.dispatch(graph, inputs, outputs)` executes; `context.readTensor()` returns correct results for the test graph. End-to-end on CPU. |
| **4** | GPU context | `createContext({devicePreference:'gpu'})` succeeds with ONNX Runtime GPU EP or DirectML. Same test graph dispatches on GPU. |
| **5** | Real model | An ONNX model (via ONNX Runtime Web with WebNN EP) runs inference. E.g. MobileNetV2 image classification. |
| **6** | WebGPU interop | `MLTensor` exported to `GPUBuffer` via WebGPU; render pipeline consumes inference output. |

### Out of scope for the lane (unless separate work)

- NPU / Neural Engine backends (future milestone after GPU works).
- Full CTS-like operator conformance.
- LiteRT.js integration (Phase C, separate lane).

---

## Integration shape

### Backend naming

Mirror the WebGPU pattern. Do not add `NGWebNNBackend_ONNX` to WebKit's
spec-level types. Keep it in repo-owned selectors:

```cpp
enum class NGWebNNProvider {
    OnnxRuntime,    // Windows (primary), Linux (fallback)
    CoreML,         // macOS / iOS
    TFLite,         // Linux / Android / ChromeOS
};

enum class NGWebNNDevice {
    Default,
    CPU,
    GPU,
    NPU,
};
```

The selector maps to the real `MLDevicePreference` only at the
`createContext()` boundary.

### WebKit source layout

```text
Source/WebCore/Modules/WebNN/
  MLContext.{h,cpp,idl}              Spec MLContext interface
  MLGraphBuilder.{h,cpp,idl}        Spec graph builder
  MLGraph.{h,cpp,idl}               Compiled graph
  MLTensor.{h,cpp,idl}              Device tensor
  MLOperand.{h,cpp,idl}             Graph operand

Source/WebCore/Modules/WebNN/Implementation/
  WebNNImpl.cpp                      Platform-neutral entry
  WebNNContextImpl.{h,cpp}           Context abstraction
  WebNNGraphImpl.{h,cpp}             Graph abstraction

  WebNNWindowsOnnxRT.{h,cpp}         Windows ONNX Runtime context
  WebNNWindowsOnnxRTGraph.{h,cpp}    Windows ONNX Runtime graph
  WebNNMacOSCoreML.{h,cpp}           macOS Core ML context (future)
  WebNNLinuxTFLite.{h,cpp}           Linux TFLite context (future)
```

### Navigator entry point

```cpp
#if ENABLE(WEBNN)
Navigator::ml() {
#if PLATFORM(WIN) && HAVE(ONNXRUNTIME)
    m_mlForWebNN = ML::create(WebNN::WindowsOnnxRTContext::create(...));
#elif PLATFORM(COCOA) && HAVE(COREML)
    m_mlForWebNN = ML::create(WebNN::MacOSCoreMLContext::create(...));
#elif HAVE(TFLITE)
    m_mlForWebNN = ML::create(WebNN::LinuxTFLiteContext::create(...));
#endif
}
#endif
```

### Build wiring (Windows)

```bash
NG_WINDOWS_ENABLE_WEBNN=1
```

CMake requirements:
- `ENABLE_WEBNN:BOOL=ON`
- `FindONNXRuntime.cmake` resolves vcpkg `onnxruntime`.
- ONNX Runtime DLLs present beside `MiniBrowser.exe`.
- Windows-only WebNN source files appended from `PlatformWin.cmake` when
  `ENABLE_WEBNN` is on.

---

## ONNX Runtime Web validation (Phase B)

Once `navigator.ml` works end-to-end, validate with ONNX Runtime Web:

```javascript
import * as ort from 'onnxruntime-web/all';

const session = await ort.InferenceSession.create('./mobilenet.onnx', {
  executionProviders: [{
    name: 'webnn',
    deviceType: 'gpu',
    powerPreference: 'high-performance',
  }]
});

const input = new ort.Tensor('float32', imageData, [1, 3, 224, 224]);
const results = await session.run({ 'input': input });
console.log('Top-1:', argmax(results['output'].data));
```

ONNX Runtime Web auto-falls back to WASM for unsupported ops, so partial
WebNN coverage is acceptable for initial validation.

### IO binding validation

```javascript
const mlContext = await navigator.ml.createContext({ deviceType: 'gpu' });
const session = await ort.InferenceSession.create('./model.onnx', {
  executionProviders: [{ name: 'webnn', context: mlContext }],
  preferredOutputLocation: 'ml-tensor'
});
// Tensors stay on device — no CPU round-trip between inference steps.
```

---

## LiteRT.js readiness tracking (Phase C)

Monitor these signals for LiteRT.js WebNN delegate readiness:

- [ ] `@litertjs/core` npm release includes `accelerator: 'webnn'` option.
- [ ] LiteRT.js WebNN delegate passes on Chromium nightly.
- [ ] GitHub issue / PR for "Exposing WebNN Options to LiteRT.js user" is
      merged.

Current status (April 2026): WebNN delegate is under active development.
`@litertjs/core` v2.4.0 supports only `'webgpu'` and `'cpu'`. When the
delegate ships, add a lane under `changes/webnn-litert/`.

---

## Acceptance ladder

1. `navigator.ml` exists.
2. `navigator.ml.createContext()` returns non-null with CPU device.
3. `MLGraphBuilder` constructs a simple graph (add, mul, relu).
4. `builder.build()` compiles the graph.
5. `context.dispatch()` executes and `readTensor()` returns correct results.
6. GPU context works (ONNX Runtime GPU EP or DirectML).
7. ONNX Runtime Web runs a real `.onnx` model through the WebNN EP.
8. `MLTensor` exports to `GPUBuffer` for WebGPU interop.

Each rung needs a build artifact and runtime probe in the standard harness.

---

## Editing rule

Change **strategy / milestones** here. Change **operations** in the
linked files, not in this section.
