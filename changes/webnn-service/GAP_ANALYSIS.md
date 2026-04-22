# WebNN / LiteRT-LM — Gap Analysis

What exists today vs. what must be built to get production-level WebNN in
the browser. Ordered by dependency — later items can't start until earlier
items are done.

---

## What exists today (in this repo)

| Item | Status |
|------|--------|
| Planning document (`docs/WEBNN_PROGRAM.md`) | Complete |
| Architecture & design (`changes/webnn-service/DESIGN.md`) | Complete |
| Change lane structure + manifest + config | Complete |
| WebIDL definitions (ML, MLContext, MLGraphBuilder, MLGraph, MLTensor, MLOperand) | Scaffolded in patch files — not applied to a WebKit checkout |
| C++ header/impl skeletons (NavigatorML, ML, spec interfaces) | Scaffolded in patch files |
| LiteRTContext / LiteRTGraph backend | **Stub only** — lifecycle compiles but `initialize()` is a no-op, `buildFromOperands()` doesn't translate ops, `run()` returns `true` without executing |
| FindLiteRT.cmake | Written but **untested against a real WebKit CMake build** |
| Platform preset (`webnn-litert`) | Registered, no green build |

**Bottom line:** The planning layer is done. The implementation layer is
scaffolding — headers and stubs that define the shape but don't execute real
inference.

---

## What must be built (production gaps)

### Gap 1: LiteRT-LM vendoring / build integration

**Problem:** LiteRT-LM is not in our dependency tree. The `FindLiteRT.cmake`
has search paths but nothing to actually find. We need LiteRT-LM to either
be built from source or vendored as pre-built binaries.

**Work required:**
- Add LiteRT-LM as a Git submodule or ExternalProject dependency, pinned to
  v0.10.2 tag.
- Bazel builds LiteRT-LM from source; we need either:
  - (a) A CMake ExternalProject that invokes Bazel inside the WebKit
    superbuild, or
  - (b) Pre-built LiteRT-LM static/shared libraries per platform, checked
    into `webkit/deps/` or fetched at build time.
- Option (b) is more practical for initial bring-up. LiteRT-LM publishes
  release assets on GitHub.
- Wire the found library into WebCore's link step via `PlatformXxx.cmake`
  for each platform.
- Abseil is a transitive dependency (LiteRT-LM uses `absl::StatusOr`,
  `absl::AnyInvocable`, etc.) — must also be resolved.

**Acceptance:** `ENABLE_WEBNN=ON` in CMakeCache, `litert_lm` library links
without undefined symbols, MiniBrowser launches.

### Gap 2: `LiteRTContext::initialize()` — real runtime init

**Problem:** `initialize()` currently does `m_initialized = true; return true;`.
It must actually load and configure LiteRT.

**Work required:**
- Load or link the LiteRT-LM shared library (`litert_lm.so` / `.dll` /
  `.dylib`).
- Create a `tflite::ErrorReporter`.
- Instantiate the XNNPACK delegate for CPU inference.
- If `devicePreference == GPU`:
  - On Windows: load DirectX / ML Drift delegate.
  - On macOS/iOS: load Metal delegate.
  - On Linux: load OpenCL delegate (if available), else fall back to CPU.
  - On Android: load OpenCL or NNAPI delegate.
- Store the delegate and allocator for later use by graph execution.
- For LLM mode: optionally pre-initialize a `litert::lm::Engine` singleton
  so model loading can be fast.

**Acceptance:** `navigator.ml.createContext({devicePreference:'cpu'})` returns
a non-null context backed by a real LiteRT runtime.

### Gap 3: Graph builder → TFLite FlatBuffer translation

**Problem:** `MLGraphBuilder` operations (add, mul, relu, conv2d, matmul,
softmax, etc.) are defined in headers and IDL but have **no implementation**.
`buildFromOperands()` is a no-op. This is the hardest piece.

**Work required:**
- Implement the MLOperand DAG walker: starting from named outputs, walk
  backwards through the operand graph collecting inputs, constants, and
  operations in topological order.
- For each MLOperand operation, emit the corresponding TFLite built-in op
  into a FlatBuffer model being constructed in memory:
  - `add` → `kTfLiteBuiltinAdd`
  - `mul` → `kTfLiteBuiltinMul`
  - `relu` → `kTfLiteBuiltinRelu`
  - `conv2d` → `kTfLiteBuiltinConv2d` (with padding/stride/layout translation)
  - `matmul` → `kTfLiteBuiltinBatchMatmul`
  - `softmax` → `kTfLiteBuiltinSoftmax`
  - `gelu` → `kTfLiteBuiltinGelu`
  - `reshape` → `kTfLiteBuiltinReshape`
  - `transpose` → `kTfLiteBuiltinTranspose`
  - `concat` → `kTfLiteBuiltinConcatenation`
  - `averagePool2d` → `kTfLiteBuiltinAveragePool2d`
  - `maxPool2d` → `kTfLiteBuiltinMaxPool2d`
  - etc. (~30 ops for initial coverage, ~95 for full spec)
- Use the TFLite FlatBuffer schema
  (`third_party/flatbuffers/include/flatbuffers/`) to serialize the model.
- Create a `tflite::Interpreter` from the in-memory FlatBuffer.
- Attach the XNNPACK (or GPU) delegate.
- Call `AllocateTensors()`.

This is significant C++ work. Chromium's implementation is ~15k lines across
`services/webnn/tflite/`. We can start with a minimal op set (add, mul, relu,
matmul, reshape) and expand.

**Acceptance:** `builder.build({output: someGraph})` produces a compiled
MLGraph backed by a real TFLite Interpreter.

### Gap 4: `LiteRTGraph::run()` — real dispatch

**Problem:** `run()` currently returns `true` without executing anything.

**Work required:**
- Map input MLTensor names to interpreter input tensor indices.
- Copy (or bind) input data to interpreter input buffers.
- Call `m_interpreter->Invoke()`.
- Copy output data from interpreter output buffers to output MLTensors.
- For GPU delegate: use delegate-managed buffers instead of memcpy.
- Handle errors from `Invoke()` and report them back to JS.

**Acceptance:** `context.dispatch(graph, inputs, outputs)` followed by
`context.readTensor(outputTensor)` returns mathematically correct results
for a simple add/mul/relu graph.

### Gap 5: Async dispatch on worker thread

**Problem:** The current dispatch is synchronous on the calling thread.
The WebNN spec says `dispatch()` and `readTensor()` are asynchronous
(timeline-ordered). Blocking the main thread would freeze the UI.

**Work required:**
- Move `Interpreter::Invoke()` to a background thread (WebKit's
  `WorkQueue` or a dedicated ML thread).
- Implement timeline ordering: writes, dispatches, and reads posted to
  the same MLContext execute in FIFO order.
- Return Promises from `readTensor()` that resolve when the queued
  dispatch completes.
- Handle cancellation if the MLContext or MLGraph is destroyed while
  work is in flight.

**Acceptance:** Inference runs without blocking the main thread. Multiple
sequential dispatches execute in order.

### Gap 6: GPU delegate path

**Problem:** CPU (XNNPACK) is the first target, but production use cases
need GPU acceleration.

**Work required:**
- Load platform-specific GPU delegate shared library:
  - Windows: `litert_gpu_delegate.dll` (DirectX / ML Drift)
  - macOS/iOS: Metal delegate (may be in LiteRT-LM prebuilt)
  - Linux: OpenCL delegate
  - Android: OpenCL or NNAPI delegate
- Ensure GPU delegate prebuilt binaries from `LiteRT-LM/prebuilt/<platform>/`
  are packaged beside the browser binary.
- Create GPU-backed MLTensors that avoid CPU round-trips.
- Handle fallback: if GPU delegate fails to load or rejects an op, fall
  back to XNNPACK transparently.

**Acceptance:** `createContext({devicePreference:'gpu'})` dispatches on GPU.
Same test graph produces correct results.

### Gap 7: WebGPU interop (`MLTensor` → `GPUBuffer`)

**Problem:** The spec defines `MLTensor` export to `GPUBuffer` for zero-copy
rendering of inference results. This requires Dawn and LiteRT to share
GPU resources.

**Work required:**
- When both ENABLE_WEBGPU and ENABLE_WEBNN are on:
  - If LiteRT GPU delegate uses the same D3D12/Vulkan/Metal device as Dawn,
    share the underlying resource handle.
  - Otherwise, copy from LiteRT output buffer to a Dawn-managed GPUBuffer.
- Implement `MLContext.createContext(gpuDevice)` where `gpuDevice` is a
  WebGPU GPUDevice.
- Implement `exportToGPU()` on MLTensor.

**Acceptance:** Inference output rendered by WebGPU pipeline without CPU
round-trip.

### Gap 8: LiteRT-LM Engine integration (LLM inference)

**Problem:** Beyond the WebNN spec's graph builder API, we want to expose
LiteRT-LM's Engine/Conversation API for running `.litertlm` models (Gemma,
Llama, Phi-4, etc.) from page JavaScript.

**Work required:**
- Define a browser-side API (or extend `navigator.ml`) for model loading
  and conversational inference.
- Initialize `litert::lm::Engine` with a model path (from Origin Private
  File System, Cache API, or a fetched blob).
- Create `Conversation` objects that manage multi-turn state.
- Expose `SendMessage` (blocking) and `SendMessageAsync` (streaming) to JS.
- Handle model download, caching, and lifecycle (models can be 1-8 GB).
- Security: validate model files, sandbox inference, enforce permissions.

This is a larger design question (new web API surface) and likely Phase 2.

**Acceptance:** A `.litertlm` model runs inference from page JavaScript
with streaming token output.

### Gap 9: Permissions, security, and privacy

**Problem:** The WebNN spec gates the API behind the `"webnn"` permissions
policy. Our implementation has no permission checks.

**Work required:**
- Implement `"webnn"` permissions policy check in `Navigator::ml()`.
- Disable in cross-origin iframes unless `allow="webnn"` is set.
- Prevent fingerprinting via `opSupportLimits()` (return conservative
  values, don't leak hardware details).
- Sandbox inference execution (already in WebKit process model, but
  verify LiteRT doesn't escape sandbox).
- Rate-limit or cap resource usage (GPU memory, compute time).

**Acceptance:** `navigator.ml` returns `undefined` in cross-origin iframes
without the permission. Feature detection doesn't leak hardware info.

### Gap 10: Operator conformance testing

**Problem:** The WebNN spec defines ~95 operations. We need to know which
ones work correctly.

**Work required:**
- Port or write tests for each implemented op against known inputs/outputs.
- Track coverage: which WebNN ops have TFLite mappings, which don't.
- For unsupported ops: either decompose into supported ops (e.g.
  `batchNormalization` = mean + variance + scale + offset) or return
  `NotSupportedError` from `opSupportLimits()`.
- Eventually run against the W3C WebNN test suite.

**Acceptance:** Documented op coverage table with pass/fail per op.

---

## Recommended build order

```
Gap 1 (vendoring)
  └─ Gap 2 (real init)
       └─ Gap 3 (graph builder, minimal ops: add/mul/relu/matmul/reshape)
            └─ Gap 4 (real dispatch)
                 └─ Gap 5 (async)
                      └─ Gap 6 (GPU delegate)
                           └─ Gap 7 (WebGPU interop)
                                └─ Gap 8 (LLM engine)
Gap 9 (permissions) — can start in parallel after Gap 2
Gap 10 (conformance) — iterative, expand with each new op
Gap 3 (full ~95 ops) — iterative, expands over many cycles
```

Gaps 1–4 get us to "a simple graph actually executes and returns correct
results." That's the first meaningful demo. Gaps 5–6 make it usable for
real workloads. Gaps 7–8 are the differentiating features. Gap 9 is
required for any public release.

---
