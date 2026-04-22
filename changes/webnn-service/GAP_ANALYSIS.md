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

**Bottom line:** The planning layer is done. Gaps 1–6 have been implemented
in the patch files — real op translation, real dispatch, async worker thread,
and GPU delegate fallback. The code needs a WebKit checkout + LiteRT-LM
libraries to actually compile and test.

---

## What must be built (production gaps)

### Gap 1: LiteRT-LM vendoring / build integration — DONE

Pinned to v0.10.2 (commit `7aee34c5d0b7c97e813707f1d5e677f4749cdcd1`).

- `webkit/deps/litert-lm.json`: Version pin, transitive deps, per-platform
  build configs, C++ API header paths.
- `webkit/deps/fetch-litert-lm.sh`: Shallow-clone fetch script.
- `FindLiteRT.cmake` with ExternalProject fallback.

**Remaining:** First actual build against a WebKit checkout to verify link
resolution. Abseil, flatbuffers, protobuf, xnnpack come transitively.

### Gap 2: `LiteRTContext::initialize()` — DONE

Creates `BuiltinOpResolver`, sets GPU preference flag, starts FIFO worker
thread for async dispatch.

### Gap 3: Graph builder → TFLite FlatBuffer translation — DONE (16 ops)

Implemented DFS topological sort of the MLOperand DAG, FlatBuffer
serialization with proper tensors/operators/buffers/subgraph, and
InterpreterBuilder. 16 ops mapped:

add, sub, mul, div, relu, sigmoid, tanh, softmax, matmul, reshape,
transpose, concat, averagePool2d, maxPool2d, conv2d, gelu.

**Remaining:** ~79 more ops for full spec coverage (layerNormalization,
batchNormalization, gemm, lstm, gru, etc.). These can be added
incrementally.

### Gap 4: `LiteRTGraph::run()` — DONE

Maps input names → interpreter tensor indices, copies data in, calls
`Invoke()`, copies results out. Returns false on any error.

### Gap 5: Async dispatch — DONE

LiteRTContext owns a `std::thread` worker with `std::mutex` /
`std::condition_variable` FIFO queue. `dispatch()` posts work;
`readTensor()` uses `std::promise`/`std::future`. Destructor signals
shutdown and joins. Timeline ordering guaranteed by single-thread FIFO.

### Gap 6: GPU delegate path — DONE

After creating interpreter, tries `TfLiteGpuDelegateV2Create` +
`ModifyGraphWithDelegate` (gated by `HAVE(LITERT_GPU_DELEGATE)`). Falls
back silently to XNNPACK on failure. Destructor cleans up delegate via
`DelegateKind` discriminator.

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

Gaps 1–6 are implemented. Gaps 7–8 are the differentiating features.
Gap 9 is required for any public release. Gap 10 is iterative.

**Next concrete step:** Build the patches against a real WebKit checkout
with LiteRT-LM libraries present to verify compilation and run the first
end-to-end test (simple add/mul/relu graph).

---
