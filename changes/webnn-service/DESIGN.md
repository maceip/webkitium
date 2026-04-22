# WebNN Runtime Design

This lane provides the ng-owned WebNN runtime path across platforms. The
integration follows the same pattern as the Windows WebGPU/Dawn lane: platform
backend implementations behind WebKit's spec-level interfaces.

## Core API Surface

WebNN exposes four primary interfaces to web content:

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

If we need a repo-owned selector, keep it outside the spec:

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

The selector maps to spec-level `MLDevicePreference` only at the
`createContext()` boundary.

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

  WebNNWindowsOnnxRT.{h,cpp}           Windows: ONNX Runtime context impl
  WebNNWindowsOnnxRTGraph.{h,cpp}      Windows: ONNX Runtime graph impl
  WebNNMacOSCoreML.{h,cpp}             macOS: Core ML context impl (future)
  WebNNLinuxTFLite.{h,cpp}             Linux: TFLite context impl (future)
  WebNNAndroidTFLite.{h,cpp}           Android: TFLite + NNAPI impl (future)
```

### Navigator Entry Point

`Navigator::ml()` is the first platform switch:

```cpp
#if ENABLE(WEBNN)
ML* Navigator::ml() {
    if (!m_ml) {
#if PLATFORM(WIN) && HAVE(ONNXRUNTIME)
        auto backend = WebNN::WindowsOnnxRTContext::create();
        m_ml = ML::create(*this, WTFMove(backend));
#elif PLATFORM(COCOA) && HAVE(COREML)
        auto backend = WebNN::MacOSCoreMLContext::create();
        m_ml = ML::create(*this, WTFMove(backend));
#elif HAVE(TFLITE)
        auto backend = WebNN::TFLiteContext::create();
        m_ml = ML::create(*this, WTFMove(backend));
#endif
    }
    return m_ml.get();
}
#endif
```

### Context Implementation (Windows / ONNX Runtime)

The Windows path loads ONNX Runtime and wraps its session/graph APIs:

```cpp
class WindowsOnnxRTContext : public WebNNContextImpl {
public:
    static std::unique_ptr<WindowsOnnxRTContext> create(NGWebNNDevice);

    // MLContext interface
    void dispatch(MLGraph&, MLNamedTensors& inputs,
                  MLNamedTensors& outputs, CompletionHandler&&) override;
    RefPtr<MLTensor> createTensor(const MLTensorDescriptor&) override;
    void readTensor(MLTensor&, CompletionHandler<void(RefPtr<ArrayBuffer>)>&&) override;
    void writeTensor(MLTensor&, const ArrayBuffer&) override;

private:
    OrtEnv* m_env = nullptr;
    OrtSession* m_session = nullptr;
    OrtMemoryInfo* m_memoryInfo = nullptr;
};
```

### Graph Builder → ONNX Runtime Mapping

The `MLGraphBuilder` operations map to ONNX Runtime's graph construction:

| WebNN Op | ONNX Op | Notes |
|----------|---------|-------|
| `add` | `Add` | Element-wise |
| `mul` | `Mul` | Element-wise |
| `conv2d` | `Conv` | With padding/stride translation |
| `relu` | `Relu` | Activation |
| `softmax` | `Softmax` | Along specified axis |
| `matmul` | `MatMul` | Linear algebra |
| `reshape` | `Reshape` | Tensor manipulation |
| `sigmoid` | `Sigmoid` | Activation |
| `tanh` | `Tanh` | Activation |
| `gelu` | `Gelu` | Transformer activation (ONNX ≥ 20) |
| `layerNormalization` | `LayerNormalization` | Normalization |

The graph builder constructs an in-memory ONNX `ModelProto` (or uses ONNX
Runtime's graph builder API). `build()` creates an `OrtSession` from the
constructed graph. `dispatch()` calls `OrtRun`.

### Tensor Management

`MLTensor` wraps `OrtValue` on Windows:

```cpp
class WebNNOnnxRTTensor : public MLTensor {
    OrtValue* m_ortValue = nullptr;
    OrtAllocator* m_allocator = nullptr;

    // For GPU tensors, may hold a D3D12/DirectML resource
    // For CPU tensors, holds a raw buffer
};
```

For GPU dispatch, ONNX Runtime's DirectML EP manages device memory. For CPU
dispatch, tensors are plain host allocations.

## WebGPU Interop

When both `ENABLE_WEBGPU` and `ENABLE_WEBNN` are on and the `MLContext` is
created from a `GPUDevice`, `MLTensor` export to `GPUBuffer` is possible:

```cpp
// In WebNNWindowsOnnxRT.cpp
RefPtr<GPUBuffer> WindowsOnnxRTContext::exportToGPU(MLTensor& tensor) {
    // If using DirectML EP, the underlying D3D12 resource can be
    // shared with Dawn's D3D12 backend via shared handle.
    // If using CPU EP, copy to a Dawn-managed buffer.
}
```

This requires Dawn and ONNX Runtime to share D3D12 device or use fence-based
synchronization. Implementation is Milestone 6.

## CMake Integration

### Windows

```cmake
# In Source/cmake/FindONNXRuntime.cmake
find_path(ONNXRUNTIME_INCLUDE_DIR onnxruntime_c_api.h
    PATHS ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/include
)
find_library(ONNXRUNTIME_LIBRARY onnxruntime
    PATHS ${VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib
)
set(ONNXRUNTIME_FOUND TRUE)
```

```cmake
# In Source/WebCore/PlatformWin.cmake
if (ENABLE_WEBNN AND ONNXRUNTIME_FOUND)
    list(APPEND WebCore_SOURCES
        Modules/WebNN/Implementation/WebNNWindowsOnnxRT.cpp
        Modules/WebNN/Implementation/WebNNWindowsOnnxRTGraph.cpp
    )
    list(APPEND WebCore_LIBRARIES ${ONNXRUNTIME_LIBRARY})
    list(APPEND WebCore_INCLUDE_DIRECTORIES ${ONNXRUNTIME_INCLUDE_DIR})
    set(HAVE_ONNXRUNTIME ON)
endif()
```

### macOS (future)

Core ML is a system framework — no vcpkg needed:

```cmake
if (ENABLE_WEBNN AND PLATFORM_COCOA)
    list(APPEND WebCore_SOURCES
        Modules/WebNN/Implementation/WebNNMacOSCoreML.cpp
    )
    list(APPEND WebCore_FRAMEWORKS CoreML)
    set(HAVE_COREML ON)
endif()
```

### Linux (future)

TFLite from system packages or vcpkg:

```cmake
if (ENABLE_WEBNN AND PLATFORM_LINUX)
    find_package(TFLite REQUIRED)
    list(APPEND WebCore_SOURCES
        Modules/WebNN/Implementation/WebNNLinuxTFLite.cpp
    )
    list(APPEND WebCore_LIBRARIES TFLite::TFLite)
    set(HAVE_TFLITE ON)
endif()
```

## Acceptance Ladder

1. `navigator.ml` exists.
2. `navigator.ml.createContext()` returns non-null with CPU device.
3. `MLGraphBuilder` constructs a simple graph (add, mul, relu).
4. `builder.build()` compiles the graph.
5. `context.dispatch()` executes and `readTensor()` returns correct results.
6. GPU context works (ONNX Runtime GPU EP or DirectML).
7. ONNX Runtime Web runs a real `.onnx` model through the WebNN EP.
8. `MLTensor` exports to `GPUBuffer` for WebGPU interop.

---
