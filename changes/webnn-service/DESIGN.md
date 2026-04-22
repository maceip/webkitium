# WebNN Runtime Design — LiteRT-LM Backend

This lane provides the ng-owned WebNN runtime path across platforms, using
**LiteRT-LM** as the unified C++ inference backend. The integration follows
the same pattern as the Windows WebGPU/Dawn lane: a single library behind
WebKit's spec-level interfaces, with platform hardware acceleration handled
internally by the library.

## Why LiteRT-LM

LiteRT-LM (v0.10.2) is Google's production-ready inference framework built on
LiteRT (successor to TFLite). It powers on-device GenAI in Chrome, Chromebook
Plus, and Pixel Watch.

Key properties for our use case:

| Property | Detail |
|----------|--------|
| **Cross-platform** | Windows, macOS, Linux, Android, iOS, IoT |
| **Hardware acceleration** | CPU (XNNPACK), GPU (ML Drift, OpenCL, DirectX), NPU (NNAPI) |
| **Chromium alignment** | TFLite/LiteRT is Chromium's WebNN backend on most platforms |
| **LLM-native** | KV-cache, tokenization, multi-turn, function calling, multi-modal |
| **Build systems** | CMake (ExternalProject_Add) and Bazel |
| **Model support** | Gemma, Llama, Phi-4, Qwen via `.litertlm` format |

Compared to ONNX Runtime (Windows-only primary) or per-platform wiring
(Core ML + TFLite + ONNX RT), LiteRT-LM gives us **one C++ integration for
all platforms** — mirroring how Dawn is our single WebGPU library.

## Core API Surface

WebNN exposes these interfaces to web content:

```
navigator.ml                    Entry point (ML interface)
  └─ createContext(options)     Creates an MLContext
       └─ MLGraphBuilder        Graph construction (~95 ops)
            └─ build()          Compiles to MLGraph
       └─ createTensor()        Device-specific tensor storage
       └─ dispatch(graph,i,o)   Execute graph
       └─ readTensor(tensor)    Read results back to CPU
```

## Backend Naming

Do not add custom backend types to WebKit's spec-level WebNN IDL. The spec
uses `MLDevicePreference` (`"cpu"`, `"gpu"`, `"npu"`) as hints, not backend
selectors.

The repo-owned selector maps to LiteRT-LM's `Backend` enum:

```cpp
// Spec-level (WebIDL)
enum MLDevicePreference { "cpu", "gpu", "npu" };

// LiteRT-LM (C++)
litert::lm::Backend::CPU   // XNNPACK-accelerated
litert::lm::Backend::GPU   // Platform GPU delegate
```

No platform switch needed — LiteRT-LM resolves the right delegate internally.

## Integration Shape

### WebKit Source Layout

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
  WebNNLiteRTContext.{h,cpp}           LiteRT-LM context impl
  WebNNLiteRTGraph.{h,cpp}             LiteRT-LM graph impl
```

### Navigator Entry Point

No platform switch — LiteRT-LM handles platform dispatch:

```cpp
#if ENABLE(WEBNN)
ML* Navigator::ml() {
    if (!m_ml) {
        auto backend = WebNN::LiteRTContext::create();
        m_ml = ML::create(*this, WTFMove(backend));
    }
    return m_ml.get();
}
#endif
```

### LiteRT-LM Context Implementation

```cpp
class LiteRTContext final : public WebNNContextImpl {
public:
    static std::unique_ptr<LiteRTContext> create(const MLContextOptions&);
    ~LiteRTContext() override;

    MLDevicePreference devicePreference() const override;

    RefPtr<MLTensor> createTensor(MLTensorDescriptor&&) override;
    void writeTensor(MLTensor&, const void* data, size_t byteLength) override;
    void readTensor(MLTensor&,
                    std::function<void(RefPtr<ArrayBuffer>)>&&) override;

    void dispatch(WebNNGraphImpl&,
                  HashMap<String, RefPtr<MLTensor>>& inputs,
                  HashMap<String, RefPtr<MLTensor>>& outputs,
                  std::function<void(bool)>&&) override;

    std::unique_ptr<WebNNGraphImpl> buildGraph(
        HashMap<String, RefPtr<MLOperand>>& outputs) override;

private:
    litert::lm::Backend m_backend;

    // For op-level graph execution (WebNN spec API):
    // LiteRT interpreter instance for compiled graphs
    std::unique_ptr<tflite::Interpreter> m_interpreter;

    // For model-level inference (LiteRT-LM):
    std::unique_ptr<litert::lm::Engine> m_engine;
};
```

### LiteRT-LM Engine for LLM Inference

For higher-level LLM inference exposed through WebNN. The key types come
from [google-ai-edge/LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM):

- `Engine` — heavyweight singleton, holds model weights
  (`runtime/engine/engine.h`)
- `Session` — stateful inference session
  (`runtime/engine/engine.h`)
- `Conversation` — high-level chat API, manages `Session` + prompt
  templating + history + tool definitions + multimodal preprocessing
  (`runtime/conversation/conversation.h`)
- `Message` — type alias for `ordered_json` (nlohmann)
  (`runtime/conversation/io_types.h`)
- `Preface` — initial context (system instructions, tools, extra_context)
  (`runtime/conversation/io_types.h`)

```cpp
#include "runtime/engine/engine.h"
#include "runtime/conversation/conversation.h"

// 1. Load model and create Engine
auto model_assets = ModelAssets::Create(model_path);
CHECK_OK(model_assets);

auto engine_settings = EngineSettings::CreateDefault(
    model_assets,
    /*backend=*/litert::lm::Backend::CPU);
    // GPU: litert::lm::Backend::GPU
    // Multimodal: add vision_backend, audio_backend params

auto engine = Engine::CreateEngine(engine_settings);
CHECK_OK(engine);

// 2. Create Conversation (lightweight, manages Session internally)
auto conversation_config = ConversationConfig::CreateDefault(**engine);
// Optional: set Preface for system instructions, tools, etc.
auto conversation = Conversation::Create(**engine, *conversation_config);
CHECK_OK(conversation);

// 3a. Blocking inference — returns complete Message
absl::StatusOr<Message> response = (*conversation)->SendMessage(
    Message{
        {"role", "user"},
        {"content", "What is the tallest building in the world?"}
    });
CHECK_OK(response);
// response is ordered_json with role="model", content=...

// 3b. Async inference — streams tokens via callback
(*conversation)->SendMessageAsync(
    Message{{"role", "user"}, {"content", prompt}},
    [](absl::StatusOr<Message> chunk) {
        if (!chunk.ok()) return;
        if (chunk->empty()) return; // end of stream
        // chunk contains partial content
    });
(*engine)->WaitUntilDone(absl::Seconds(30));
```

#### Multimodal (vision + audio)

```cpp
auto engine_settings = EngineSettings::CreateDefault(
    model_assets,
    /*backend=*/litert::lm::Backend::CPU,
    /*vision_backend=*/litert::lm::Backend::GPU,
    /*audio_backend=*/litert::lm::Backend::CPU);

// content is an array of typed parts
Message msg{
    {"role", "user"},
    {"content", {
        {{"type", "text"}, {"text", "Describe this image:"}},
        {{"type", "image"}, {"path", "/path/to/image.jpg"}}
    }}
};
auto response = (*conversation)->SendMessage(msg);
```

#### Function calling (tool use)

```cpp
Preface preface = JsonPreface({
    .tools = {
        {{"name", "get_weather"},
         {"description", "Returns weather for a location"},
         {"parameters", {{"type", "object"},
             {"properties", {{"location", {{"type", "string"}}}}},
             {"required", {"location"}}}}}
    }
});
auto config = ConversationConfig::CreateDefault(**engine);
// attach preface to config
```

### Op-Level Graph Execution (WebNN Spec API)

For the standard WebNN graph builder API, we use LiteRT's core runtime
(not the LM orchestration layer):

```cpp
// MLGraphBuilder operations map to TFLite built-in ops
// Graph builder constructs a TFLite FlatBuffer model in memory
// build() creates a TFLite Interpreter from the model
// dispatch() calls Interpreter::Invoke()

bool LiteRTGraph::run(
    HashMap<String, RefPtr<MLTensor>>& inputs,
    HashMap<String, RefPtr<MLTensor>>& outputs)
{
    // 1. Bind input tensors to interpreter input buffers
    for (auto& [name, tensor] : inputs) {
        auto* input = m_interpreter->typed_input_tensor<float>(
            m_inputIndices[name]);
        memcpy(input, tensor->data(), tensor->byteLength());
    }

    // 2. Invoke
    if (m_interpreter->Invoke() != kTfLiteOk)
        return false;

    // 3. Copy output tensors
    for (auto& [name, tensor] : outputs) {
        auto* output = m_interpreter->typed_output_tensor<float>(
            m_outputIndices[name]);
        memcpy(tensor->data(), output, tensor->byteLength());
    }
    return true;
}
```

### WebNN Op → TFLite Built-in Op Mapping

| WebNN Op | TFLite Built-in Op | Notes |
|----------|-------------------|-------|
| `add` | `kTfLiteBuiltinAdd` | Element-wise |
| `mul` | `kTfLiteBuiltinMul` | Element-wise |
| `sub` | `kTfLiteBuiltinSub` | Element-wise |
| `div` | `kTfLiteBuiltinDiv` | Element-wise |
| `relu` | `kTfLiteBuiltinRelu` | Activation |
| `sigmoid` | `kTfLiteBuiltinLogistic` | Activation |
| `tanh` | `kTfLiteBuiltinTanh` | Activation |
| `softmax` | `kTfLiteBuiltinSoftmax` | Along axis |
| `conv2d` | `kTfLiteBuiltinConv2d` | With padding/stride |
| `matmul` | `kTfLiteBuiltinBatchMatmul` | Linear algebra |
| `reshape` | `kTfLiteBuiltinReshape` | Tensor manipulation |
| `transpose` | `kTfLiteBuiltinTranspose` | Tensor manipulation |
| `concat` | `kTfLiteBuiltinConcatenation` | Along axis |
| `averagePool2d` | `kTfLiteBuiltinAveragePool2d` | Pooling |
| `maxPool2d` | `kTfLiteBuiltinMaxPool2d` | Pooling |
| `batchNormalization` | Custom (decomposed) | mean/variance/scale/offset |
| `layerNormalization` | Custom (decomposed) | Reduced + normalized |
| `gelu` | `kTfLiteBuiltinGelu` | TFLite ≥ 2.12 |
| `gemm` | `kTfLiteBuiltinFullyConnected` | With optional bias |

## CMake Integration

### LiteRT-LM as ExternalProject

```cmake
include(ExternalProject)

if (ENABLE_WEBNN)
    ExternalProject_Add(litert_lm
        GIT_REPOSITORY https://github.com/google-ai-edge/LiteRT-LM.git
        GIT_TAG v0.10.2
        SOURCE_DIR ${CMAKE_BINARY_DIR}/litert-lm-src
        BINARY_DIR ${CMAKE_BINARY_DIR}/litert-lm-build
        CMAKE_ARGS
            -DLITERTLM_PROJECT_ROOT=${CMAKE_BINARY_DIR}/litert-lm-src
        INSTALL_COMMAND ""
        BUILD_ALWAYS FALSE
    )

    set(LITERT_LM_INCLUDE_DIR ${CMAKE_BINARY_DIR}/litert-lm-src)
    set(LITERT_LM_LIB_DIR ${CMAKE_BINARY_DIR}/litert-lm-build)
endif()
```

### Pre-built library path

For faster builds, pre-built LiteRT-LM libraries can be used:

```cmake
if (ENABLE_WEBNN)
    find_path(LITERT_LM_INCLUDE_DIR
        NAMES runtime/engine/engine.h
        PATHS ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/include/litert-lm
              /usr/local/include/litert-lm
    )
    find_library(LITERT_LM_LIBRARY
        NAMES litert_lm litert-lm
        PATHS ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib
              /usr/local/lib
    )
endif()
```

### WebKit PlatformXxx.cmake

```cmake
if (ENABLE_WEBNN AND LITERT_LM_FOUND)
    list(APPEND WebCore_SOURCES
        Modules/WebNN/Implementation/WebNNContextImpl.cpp
        Modules/WebNN/Implementation/WebNNGraphImpl.cpp
        Modules/WebNN/Implementation/WebNNLiteRTContext.cpp
        Modules/WebNN/Implementation/WebNNLiteRTGraph.cpp
    )
    list(APPEND WebCore_PRIVATE_INCLUDE_DIRECTORIES
        ${LITERT_LM_INCLUDE_DIR})
    list(APPEND WebCore_LIBRARIES ${LITERT_LM_LIBRARY})
    SET_AND_EXPOSE_TO_BUILD(HAVE_LITERT ON)
endif()
```

## Build Dependencies

| Dependency | Purpose | Source |
|-----------|---------|--------|
| LiteRT-LM v0.10.2 | Inference runtime | `ExternalProject` or pre-built |
| protobuf | Model serialization | Fetched by LiteRT-LM build |
| flatbuffers | TFLite model format | Fetched by LiteRT-LM build |
| Git LFS | GPU prebuilt binaries | System install |
| Bazel 7.6.1 | Source builds (optional) | System install |

## Prebuilt GPU Libraries

LiteRT-LM ships prebuilt native GPU accelerator binaries per platform in
`prebuilt/<platform>/`. These use **native GPU APIs directly** (DirectX,
Metal, OpenCL) — **no WebGPU is involved**. Copy them beside the browser
binary at runtime.

| Platform | Key GPU libraries | Native API |
|----------|------------------|------------|
| Windows x86_64 | `libLiteRt.dll` | DirectX (GPU path built into core lib) |
| macOS arm64 | `libLiteRtMetalAccelerator.dylib`, `libLiteRt.dylib` | Metal |
| Linux x86_64 | `libLiteRt.so` | CPU (XNNPACK); OpenCL via WebGpuAccelerator for Dawn path |
| Linux arm64 | `libLiteRt.so` | CPU (XNNPACK) |
| Android arm64 | `libLiteRtGpuAccelerator.so`, `libLiteRtOpenClAccelerator.so` | OpenCL, native GPU |
| Android x86_64 | `libLiteRtGpuAccelerator.so`, `libLiteRtOpenClAccelerator.so` | OpenCL, native GPU |
| iOS arm64 | `libGemmaModelConstraintProvider.dylib` | Core ML (via LiteRT delegate) |

All platforms also ship `libGemmaModelConstraintProvider` for constrained
decoding with Gemma models.

Git LFS is required to fetch the actual binaries (without LFS they are
pointer files). Run `git lfs pull` after cloning.

## WebGPU Interop

When both `ENABLE_WEBGPU` and `ENABLE_WEBNN` are on and the `MLContext` is
created from a `GPUDevice`, `MLTensor` export to `GPUBuffer` is possible:

```cpp
RefPtr<GPUBuffer> LiteRTContext::exportToGPU(MLTensor& tensor) {
    // LiteRT GPU delegate may use the same underlying GPU device.
    // If Dawn and LiteRT share a D3D12/Vulkan/Metal device, the
    // tensor buffer can be shared via platform handle.
    // Otherwise, copy from LiteRT output buffer to Dawn-managed buffer.
}
```

## Acceptance Ladder

1. `navigator.ml` exists.
2. `navigator.ml.createContext()` returns non-null with CPU device.
3. `MLGraphBuilder` constructs a simple graph (add, mul, relu).
4. `builder.build()` compiles the graph via LiteRT interpreter.
5. `context.dispatch()` executes and `readTensor()` returns correct results.
6. GPU context works via LiteRT GPU delegate.
7. LiteRT-LM runs a `.litertlm` model from page JavaScript.
8. `MLTensor` exports to `GPUBuffer` for WebGPU interop.
9. Same integration verified on Windows + at least one other platform.

---
