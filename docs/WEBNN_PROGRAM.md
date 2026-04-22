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
a graph-construction → compile → dispatch model.

### Relationship to WebGPU

WebNN and WebGPU are **complementary**, not competing:

| Concern | WebGPU | WebNN |
|---------|--------|-------|
| Primary workload | Graphics rendering + general compute shaders | Neural-network inference |
| Programming model | Write WGSL shaders, manage buffers/pipelines | Declare a computation graph, dispatch |
| Hardware target | GPU (D3D12, Vulkan, Metal) | GPU, CPU, or NPU via ML runtime |
| Interop | `GPUBuffer`, `GPUTexture` | `MLTensor` can export to `GPUBuffer` |

A typical pipeline: capture frame → WebNN inference (detection /
segmentation) → WebGPU render (overlay / post-process). Our browser must
support both.

---

## Strategy

### Approach evaluation

Three integration approaches were evaluated:

#### 1. ONNX Runtime (per-platform, Windows-primary)

ONNX Runtime is Microsoft's inference engine. Ships with Windows 11 24H2+ and
is the default WebNN backend in Chromium on Windows.

**Pros:** Deep Windows integration. `.onnx` model format.
**Cons:** Not the primary backend on non-Windows platforms. Would need
separate Core ML (macOS), TFLite (Linux/Android) backends — meaning three
C++ integrations instead of one. No unified cross-platform story.

#### 2. LiteRT-LM (unified C++ across all platforms) ← CHOSEN

[LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) (v0.10.2, April
2026) is Google's production-ready C++ inference framework built on LiteRT
(successor to TensorFlow Lite). It already powers on-device GenAI in
**Chrome**, **Chromebook Plus**, and **Pixel Watch**.

**Pros:**
- **One C++ library for all platforms**: Windows, macOS, Linux, Android, iOS,
  and IoT (Raspberry Pi).
- **Hardware acceleration built in**: CPU (XNNPACK), GPU (ML Drift / OpenCL /
  DirectX on Windows), NPU via platform delegates.
- **Already the Chromium WebNN backend**: TFLite/LiteRT is the inference
  engine Chromium uses for WebNN on ChromeOS, Linux, Android, and as a
  fallback on Windows and macOS.
- **LLM-native**: `Engine`/`Conversation` API handles KV-cache, tokenization,
  session cloning, prompt templating, function calling.
- **Multi-modal**: vision, audio, and text inputs.
- **CMake build support**: `CMakeLists.txt` with `ExternalProject_Add`, plus
  Bazel for source builds.
- **Broad model support**: Gemma, Llama, Phi-4, Qwen, and more via
  `.litertlm` format.

**Cons:** Bazel-primary build (CMake is available but less documented).
Requires protobuf and flatbuffers as build dependencies.

#### 3. Direct per-platform wiring (Core ML, TFLite, ONNX RT)

Wire each platform to its native ML runtime individually.

**Pros:** Tightest integration. Uses Chromium's exact backend per platform.
**Cons:** Three+ separate C++ implementations to maintain. Enormous surface
area. LiteRT-LM effectively subsumes this — it wraps TFLite delegates
underneath and handles platform dispatch internally.

### Decision: LiteRT-LM

**LiteRT-LM is the unified C++ backend for WebNN across all platforms.**

Rationale:
1. **One codebase**: A single C++ integration covers Windows, macOS, Linux,
   Android, iOS, and embedded. This mirrors how Dawn is the single WebGPU
   library for all platforms.
2. **Production-proven**: Already shipping in Chrome and Chromebook Plus for
   on-device GenAI.
3. **Chromium alignment**: Chromium uses TFLite/LiteRT as its WebNN backend
   on most platforms. LiteRT-LM is the GenAI orchestration layer on top.
4. **Hardware acceleration without delegate management**: GPU and NPU
   acceleration is handled internally by LiteRT-LM via the `Backend` enum
   (`CPU`, `GPU`), not by manual delegate configuration.
5. **Future-proof**: LiteRT-LM is actively developed (v0.10.2, 4.1k+ stars),
   with new model support and platform capabilities arriving regularly.

---

## Integration shape

### LiteRT-LM C++ API

The integration uses LiteRT-LM's `Engine` / `Conversation` / `Session` API
from [google-ai-edge/LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM)
(v0.10.2, Apache-2.0):

```cpp
#include "runtime/engine/engine.h"         // Engine, Session, ModelAssets
#include "runtime/conversation/conversation.h"  // Conversation, Message

// 1. Load model and create Engine (heavyweight, holds weights)
auto model_assets = ModelAssets::Create(model_path);
auto engine_settings = EngineSettings::CreateDefault(
    model_assets, litert::lm::Backend::CPU);
auto engine = Engine::CreateEngine(engine_settings);

// 2. Create Conversation (lightweight, manages Session + history +
//    prompt templates + tool definitions + multimodal preprocessing)
auto config = ConversationConfig::CreateDefault(**engine);
auto conversation = Conversation::Create(**engine, *config);

// 3. Blocking inference — Message is ordered_json
auto result = (*conversation)->SendMessage(
    Message{{"role", "user"}, {"content", prompt}});

// 4. Streaming inference — token-by-token via callback
(*conversation)->SendMessageAsync(message, callback);
(*engine)->WaitUntilDone(absl::Seconds(30));
```

Backend selection:
- `litert::lm::Backend::CPU` — XNNPACK-accelerated CPU inference
- `litert::lm::Backend::GPU` — Platform GPU delegate (ML Drift on Android,
  OpenCL, DirectX on Windows, Metal on macOS/iOS)

Capabilities beyond basic inference:
- Multi-modal (vision + audio) via `vision_backend` / `audio_backend`
- Function calling / tool use via `Preface.tools`
- Constrained decoding (regex, JSON schema, Lark grammar)
- Session cloning for speculative decoding
- Jinja prompt templates (Minja C++ engine)
- Supported models: Gemma, Llama, Phi-4, Qwen, SmolLM, and more

### Dual-layer integration

WebNN has two integration points in our browser:

**Layer 1: WebNN spec API (`navigator.ml`)** — The low-level graph
construction/dispatch API that web content uses directly. Backed by LiteRT
(the core runtime) for op-level graph execution.

**Layer 2: LiteRT-LM orchestration** — The higher-level LLM engine that web
content can use via WebNN for model-level inference. Handles tokenization,
KV-cache, multi-turn conversations, tool use, and multi-modal inputs.

Both layers use the same underlying LiteRT runtime for hardware-accelerated
execution.

### WebKit source layout

```text
Source/WebCore/Modules/WebNN/
  Navigator+ML.{h,cpp,idl}             navigator.ml property
  ML.{h,cpp,idl}                       ML interface (createContext)
  MLContext.{h,cpp,idl}                 Context: dispatch, tensor lifecycle
  MLGraphBuilder.{h,cpp,idl}           Graph construction API
  MLGraph.{h,cpp,idl}                  Compiled graph
  MLTensor.{h,cpp,idl}                 Opaque device tensor
  MLOperand.{h,cpp,idl}                Graph node / intermediate value

Source/WebCore/Modules/WebNN/Implementation/
  WebNNContextImpl.{h,cpp}             Abstract context backend interface
  WebNNGraphImpl.{h,cpp}               Abstract graph backend interface
  WebNNLiteRTContext.{h,cpp}           LiteRT-LM context (all platforms)
  WebNNLiteRTGraph.{h,cpp}             LiteRT-LM graph (all platforms)
```

### Navigator entry point

```cpp
#if ENABLE(WEBNN)
ML* Navigator::ml() {
    if (!m_ml) {
        auto backend = WebNN::LiteRTContext::create(devicePreference);
        m_ml = ML::create(*this, WTFMove(backend));
    }
    return m_ml.get();
}
#endif
```

No platform switch needed — LiteRT-LM handles platform dispatch internally.

### Build wiring

LiteRT-LM builds with CMake via `ExternalProject_Add` or as a pre-built
library. For our WebKit integration:

```bash
NG_ENABLE_WEBNN=1
```

CMake requirements:
- `ENABLE_WEBNN:BOOL=ON`
- `FindLiteRT.cmake` resolves pre-built LiteRT-LM libraries or builds from
  source via `ExternalProject_Add`.
- LiteRT-LM shared libraries present beside the browser binary.
- WebNN source files compiled when `ENABLE_WEBNN` is on.

Build dependencies:
- Bazel 7.6.1 (for source builds) or pre-built libraries
- protobuf, flatbuffers (fetched by LiteRT-LM build)
- Git LFS (for GPU prebuilt binaries)

### Platform-specific notes

| Platform | Backend | GPU acceleration | Build notes |
|----------|---------|-----------------|-------------|
| Windows | LiteRT-LM | DirectX / ML Drift | `--config=windows` Bazel flag; requires VS 2022 MSVC |
| macOS | LiteRT-LM | Metal (via LiteRT GPU delegate) | `xcode-select --install` for clang |
| Linux | LiteRT-LM | OpenCL (if available) | Standard clang build |
| Android | LiteRT-LM | GPU delegate / NNAPI (NPU) | NDK r28b+; `--config=android_arm64` |
| iOS | LiteRT-LM | Core ML delegate | Swift API coming soon; C++ available |

---

## Milestones

| # | Milestone | Exit (must all be true) |
|---|-----------|-------------------------|
| **1** | Foundations | `ENABLE_WEBNN=ON` in cache; LiteRT-LM libs loadable beside MiniBrowser; `navigator.ml` exists in JS. |
| **2** | Context + graph build | `navigator.ml.createContext({devicePreference:'cpu'})` succeeds; `MLGraphBuilder` constructs a simple add/mul graph; `builder.build()` compiles via LiteRT. |
| **3** | Dispatch + readback | `context.dispatch(graph, inputs, outputs)` executes; `context.readTensor()` returns correct results. End-to-end CPU inference. |
| **4** | GPU context | `createContext({devicePreference:'gpu'})` succeeds with LiteRT GPU delegate. Same test graph dispatches on GPU. |
| **5** | LLM inference | LiteRT-LM `Engine`/`Conversation` runs a `.litertlm` model (e.g. Gemma) from page JavaScript. |
| **6** | WebGPU interop | `MLTensor` exported to `GPUBuffer` via WebGPU; render pipeline consumes inference output. |
| **7** | Multi-platform | Same integration verified on at least Windows + one non-Windows platform (Linux or macOS). |

### Out of scope for the lane (unless separate work)

- NPU delegation (future milestone after GPU works).
- Full CTS-like operator conformance.
- ONNX model support (LiteRT-LM uses `.litertlm` format; ONNX conversion is
  separate tooling).

---

## ONNX Runtime Web validation (secondary)

Once `navigator.ml` works end-to-end with LiteRT, ONNX Runtime Web can be
used as a secondary validation path. ONNX Runtime Web's WebNN EP delegates to
whatever `navigator.ml` implementation the browser provides — in our case,
LiteRT-LM.

```javascript
import * as ort from 'onnxruntime-web/all';
const session = await ort.InferenceSession.create('./model.onnx', {
  executionProviders: [{ name: 'webnn', deviceType: 'gpu' }]
});
```

This validates that third-party frameworks can consume our WebNN
implementation.

---

## LiteRT.js readiness tracking

LiteRT.js (`@litertjs/core`) is the JS-side runtime. Its WebNN delegate is
under development. When it ships, it provides a higher-level JS API on top
of our LiteRT-LM C++ backend:

- [ ] `@litertjs/core` npm release includes `accelerator: 'webnn'` option.
- [ ] LiteRT.js WebNN delegate passes on our browser.

Current status (April 2026): v2.4.0 supports `'webgpu'` and `'cpu'` only.

---

## Acceptance ladder

1. `navigator.ml` exists.
2. `navigator.ml.createContext()` returns non-null with CPU device.
3. `MLGraphBuilder` constructs a simple graph (add, mul, relu).
4. `builder.build()` compiles the graph via LiteRT.
5. `context.dispatch()` executes and `readTensor()` returns correct results.
6. GPU context works via LiteRT GPU delegate.
7. LiteRT-LM runs a real `.litertlm` model from page JavaScript.
8. `MLTensor` exports to `GPUBuffer` for WebGPU interop.
9. Same integration works on Windows + at least one other platform.

Each rung needs a build artifact and runtime probe in the standard harness.

---

## Editing rule

Change **strategy / milestones** here. Change **operations** in the
linked files, not in this section.
