# Chromium On-Device ML Internals: Model Management, WebNN, and Prompt API

> Research compiled April 23, 2026  
> Sources: Chromium source (chromium.googlesource.com), Chrome developer docs, commit history

---

## Table of Contents

1. [Model Download](#1-model-download)
2. [Model Storage](#2-model-storage)
3. [KV Cache Management](#3-kv-cache-management)
4. [Backend Selection (CPU/GPU/NPU)](#4-backend-selection)
5. [Prompt API (window.ai / LanguageModel) Model Provisioning](#5-prompt-api-model-provisioning)

---

## 1. Model Download

### Two Separate Systems

Chromium has **two distinct ML subsystems** with different download mechanisms:

| System | Purpose | Download Mechanism |
|--------|---------|-------------------|
| **WebNN** (`services/webnn/`) | Low-level graph-based ML inference API (`navigator.ml`) | No model download — web content supplies its own model weights |
| **On-Device AI / Prompt API** (`chrome/browser/ai/`, `services/on_device_model/`) | Built-in Gemini Nano for `LanguageModel.create()`, Summarizer, Writer, etc. | Component Updater via Optimization Guide |

### WebNN: No Model Download

WebNN does **not** download models. It is a compute API: web content constructs computation graphs via `MLGraphBuilder`, or frameworks like ONNX Runtime Web load `.onnx` files from the web. The browser provides the hardware-accelerated backend but not the model.

### On-Device AI: Component Updater + Optimization Guide

Gemini Nano (the model behind `LanguageModel.create()` and other built-in APIs) is downloaded by the **Component Updater** via the **Optimization Guide** infrastructure.

#### Key Source Files

```
chrome/browser/component_updater/
  optimization_guide_on_device_model_installer.h
  optimization_guide_on_device_model_installer.cc

components/optimization_guide/
  core/model_execution/
  core/optimization_guide_features.h

chrome/browser/optimization_guide/
  optimization_guide_keyed_service.h
  optimization_guide_keyed_service.cc
```

#### Key Classes

| Class | Role |
|-------|------|
| `OptimizationGuideOnDeviceModelInstallerPolicy` | Extends `ComponentInstallerPolicy`. Handles model verification, installation, and updates |
| `OnDeviceModelComponentStateManager` | Manages component state transitions (not installed → downloading → ready) |
| `OptimizationGuideKeyedService` | Per-profile keyed service that coordinates model availability |
| `ManifestAssetManagerDelegateImpl` | Registers the component and listens for readiness |

#### Download Protocol

The Component Updater uses the **Omaha protocol** (Google's update protocol, same as Chrome browser updates). The flow:

1. Chrome calls the update server at `update.googleapis.com/service/update2` with a check request containing the component's `appid` (extension ID).
2. The server responds with the latest version URL if an update is available.
3. The download URL points to `edgedl.me.gvt1.com` or `dl.google.com` (standard Google CDN for component downloads). Components are delivered as **CRX files** (signed ZIP archives containing a `manifest.json` + payload).
4. The CRX is verified (signature check), unpacked, and registered with the component updater.

#### Download Triggers

- **First API call**: The initial download is triggered by the first call to any `*.create()` function (e.g., `LanguageModel.create()`, `Summarizer.create()`).
- **GPU performance check**: Before downloading, Chrome runs a representative GPU shader to estimate device performance. Based on results, it downloads either a larger (4B parameters) or smaller (2B parameters) Gemini Nano variant.
- **CPU fallback**: If GPU doesn't meet requirements but CPU does (16GB RAM, 4+ cores), the CPU inference variant is downloaded.
- **Scam detection trigger**: `availability()` can trigger a download if the Gemini Nano-powered scam detection feature is active.

#### Download Resilience

- Interrupted downloads resume from where they left off.
- Downloads continue in background if the triggering tab is closed.
- Downloads persist across browser restarts within a 30-day window.

#### Model Updates

- Checked at browser startup.
- LoRA weight updates checked daily.
- Every update is a **full model download** (no delta/patch updates — weight diffs are too complex to compute efficiently).
- Hot-swapped at runtime: new API calls immediately use the updated model with no downtime.

#### Model Types

The installer supports multiple model types via the `OnDeviceModelType` enum:

```cpp
// chrome/browser/component_updater/optimization_guide_on_device_model_installer.h
enum class OnDeviceModelType {
  kBaseModel,
  kClassifierModel,
};
```

Each type has its own extension ID retrieved via `GetOptimizationGuideOnDeviceModelExtensionId()`.

---

## 2. Model Storage

### On-Device AI Model Storage (Gemini Nano)

#### Disk Location

Models are stored **system-wide** (not per-profile) in the Chrome user data directory:

| Platform | Path |
|----------|------|
| **Windows** | `%LOCALAPPDATA%\Google\Chrome\User Data\OptGuideOnDeviceModel\` |
| **macOS** | `~/Library/Application Support/Google/Chrome/OptGuideOnDeviceModel/` |
| **Linux** | `~/.config/google-chrome/OptGuideOnDeviceModel/` |
| **ChromeOS** | Managed by the system component updater infrastructure |

The model lives **outside** any specific profile directory — it is shared across all profiles on the machine.

#### File Format

- **`weights.bin`**: The primary model weights file (1.5–4 GB depending on variant). This is a proprietary binary format loaded via `ChromeMLModelData.weights_file` as a memory-mapped file (`base::MemoryMappedFile`).
- **Weight cache files**: `ChromeMLModelData` also includes `cache_file`, `encoder_cache_file`, and `adapter_cache_file` handles for pre-computed weight caches.
- **LoRA weights**: Stored alongside the base model for APIs that use Low-Rank Adaptation (e.g., Proofreader API). Purged after a 30-day grace period when the base model is deleted.
- **Sentencepiece model**: For APU backend models, a separate `sentencepiece_model_path` is required. Other backends embed the tokenizer inside the weights file.

#### Component Format

From the component updater's perspective:

```
OptGuideOnDeviceModel/
  <version>/
    manifest.json     ← component metadata (version, name)
    weights.bin        ← model weights
    ...                ← additional model files
```

#### Storage Quotas and Eviction

Chrome actively manages disk space:

- **Automatic deletion**: The Gemini Nano model is automatically deleted if the device's free disk space drops below a threshold.
- **Inactivity purge**: The model is purged if a user hasn't met eligibility criteria for 30 days (criteria include API usage and device capability).
- **Enterprise policy**: An enterprise policy can force model deletion.
- **No graceful shutdown**: The model can be deleted at any time, even mid-session, without regard for running prompts. An API that was available at session start can suddenly become unavailable.
- **No auto re-download**: After purge, re-download must be triggered by a new `*.create()` call.
- **LoRA grace period**: When the base model is purged, related LoRA weights are purged after a 30-day grace period.

#### Hardware Requirements for Download

| Requirement | Threshold |
|-------------|-----------|
| **Storage** | At least 22 GB free disk space |
| **GPU VRAM** | Strictly more than 4 GB (required for audio input) |
| **CPU RAM** | 16 GB minimum (alternative to GPU path) |
| **CPU cores** | 4+ cores |
| **Network** | Unlimited/unmetered connection |

### WebNN Model Storage

WebNN itself doesn't manage model storage. Models come from:
- Web content (fetched via `fetch()`, served from app servers or CDNs)
- Cache API / Origin Private File System (OPFS) for persistence
- IndexedDB for smaller model components

The browser's standard HTTP cache, Service Worker cache, or OPFS handle persistence — WebNN has no opinion on this.

---

## 3. KV Cache Management

### Architecture: ChromeML Shared Library

KV cache for LLM inference is managed **entirely within the ChromeML shared library** — Chrome layers nothing on top. The ChromeML library is a closed-source shared library (`.dll`/`.dylib`/`.so`) that Chrome loads at runtime for on-device model inference.

#### Key Source Files

```
services/on_device_model/ml/
  chrome_ml.h                    ← ChromeML loader/wrapper
  chrome_ml_api.h                ← C API function table (exported by ChromeML .so/.dll)
  chrome_ml_types.h              ← Types: ModelBackendType, InputPiece, etc.
  on_device_model_executor.h     ← OnDeviceModelExecutor, SessionImpl
  session_accessor.h             ← SessionAccessor for thread-safe session access
```

#### Session-Based Context Management

The ChromeML API uses **sessions** as the fundamental unit for managing inference state (which includes the KV cache):

```cpp
// chrome_ml_api.h — key session functions:
ChromeMLSession (*CreateSession)(ChromeMLModel model,
                                 const ChromeMLAdaptationDescriptor* descriptor);
ChromeMLSession (*CloneSession)(ChromeMLSession session);
void (*DestroySession)(ChromeMLSession session);

bool (*SessionAppend)(ChromeMLSession session,
                      const ChromeMLAppendOptions* options,
                      ChromeMLCancel cancel);
bool (*SessionGenerate)(ChromeMLSession session,
                        const ChromeMLGenerateOptions* options,
                        ChromeMLCancel cancel);
```

The session opaquely holds:
- The KV cache state (populated during `SessionAppend` / prefill)
- The current token position
- Any adaptation state

#### Append/Generate Pattern

As of April 2025, Chrome migrated from a single `SessionExecuteModel()` to a two-phase pattern:

1. **`SessionAppend()`** — Processes input tokens (prefill). Populates the KV cache. Reports the number of tokens processed via `ChromeMLContextSavedFn` callback.
2. **`SessionGenerate()`** — Auto-regressive decoding. Reads from the KV cache populated by Append. Streams tokens via `ChromeMLGenerateOutputFn` callback.

This separation enables efficient multi-turn conversations: append new user input to an existing session without re-processing the full context.

#### Session Cloning (KV Cache Sharing)

```cpp
ChromeMLSession (*CloneSession)(ChromeMLSession session);
```

`CloneSession` creates a copy of a session **including its KV cache state**. This enables:
- **Speculative decoding**: Clone a session, run draft tokens on the clone, verify against the original.
- **Multi-turn branching**: Fork a conversation at a point without re-computing the prefix.

In the Chromium-side wrapper (`on_device_model_executor.h`):

```cpp
class SessionImpl final : public on_device_model::BackendSession {
  std::unique_ptr<BackendSession> Clone() override;
  // ...
  SessionAccessor::Ptr session_;           // wraps ChromeMLSession
  const uint32_t max_tokens_;              // max context window
  std::set<std::unique_ptr<ContextHolder>> context_holders_;
};
```

#### Max Tokens / Context Window

The context window is set at model creation time via `ChromeMLModelDescriptor::max_tokens`:

```cpp
struct ChromeMLModelDescriptor {
  uint32_t max_tokens;    // Maximum input+output tokens the model can handle
  float temperature;
  int top_k;
  int num_draft_tokens;   // For speculative decoding
  // ...
};
```

This value flows through to `SessionImpl::max_tokens_` and `OnDeviceModelExecutor::max_tokens_`.

#### Weight Caching

`ChromeMLModelData` includes separate file handles for pre-computed weight caches:

```cpp
struct ChromeMLModelData {
  PlatformFile weights_file;
  PlatformFile cache_file;           // Weight cache
  PlatformFile encoder_cache_file;   // Encoder weight cache
  PlatformFile adapter_cache_file;   // Adaptation weight cache
};
```

These are pre-computed transformations of the model weights (e.g., quantized/tiled for the target hardware) — distinct from the KV cache used during inference.

#### Summary

| Aspect | Implementation |
|--------|---------------|
| KV cache management | Fully inside ChromeML shared library |
| Chrome's role | Creates/destroys sessions, calls Append/Generate |
| Persistence | In-memory only; destroyed when session is destroyed |
| Sharing | Via `CloneSession()` |
| Context window | `max_tokens` in `ChromeMLModelDescriptor` |
| WebNN KV cache | Not applicable — WebNN is a graph compute API, not an LLM runtime |

---

## 4. Backend Selection (CPU/GPU/NPU)

### Two Separate Backend Selection Systems

#### A. WebNN Backend Selection (`services/webnn/`)

WebNN selects backends at context creation time based on the `devicePreference` hint from JavaScript and platform availability.

##### Decision Logic in `webnn_context_provider_impl.cc`

The `CreateWebNNContext()` method in `WebNNContextProviderImpl` follows this priority chain:

```
1. [Testing backend override]
   if (g_backend_for_testing) → use test backend

2. [Windows + ORT]
   if IS_WIN && ort::ShouldCreateOrtContext(*options) → create ORT context
     - Calls gpu_host_->EnsureWebNNExecutionProvidersReady()
     - Creates ort::ContextImplOrt

3. [Apple + CoreML]  
   if IS_APPLE && macOS ≥ 14.4 && kWebNNCoreML enabled && not incognito
     && (macOS: ARM CPU only) → create CoreML context
     - Creates coreml::ContextImplCoreml

4. [LiteRT backend]
   if WEBNN_USE_LITERT && kWebNNLiteRT enabled → create LiteRT context
     - Creates litert::ContextImplLiteRt

5. [TFLite fallback]
   if WEBNN_USE_TFLITE → create TFLite context
     - Creates tflite::ContextImplTflite

6. [Not supported]
   → return kNotSupportedError
```

##### Build Flags

| Build Flag | Meaning |
|-----------|---------|
| `BUILDFLAG(IS_WIN)` | Enables ORT (ONNX Runtime) backend path |
| `BUILDFLAG(IS_APPLE)` | Enables CoreML backend path |
| `BUILDFLAG(WEBNN_USE_TFLITE)` | Enables TFLite backend |
| `BUILDFLAG(WEBNN_USE_LITERT)` | Enables LiteRT backend (newer TFLite successor) |

##### Feature Flags

| Feature | Chrome Flag | Effect |
|---------|------------|--------|
| `kWebNNCoreML` | `--enable-features=WebNNCoreML` | Enable CoreML backend on Apple platforms |
| `kWebNNLiteRT` | `--enable-features=WebNNLiteRT` | Enable LiteRT backend |
| `kWebNNOnnxRuntime` | `--enable-features=WebNNOnnxRuntime` | Enable ORT backend on Windows |

##### Device Type Enum (Mojom)

```cpp
// services/webnn/public/mojom/webnn_context_provider.mojom
enum Device {
  kCpu = 0,
  kGpu = 1,
  kNpu = 2,
};
```

Recorded to UMA via `WebNN.DeviceType` histogram.

##### Per-Platform Backend Matrix

| Platform | `kCpu` | `kGpu` | `kNpu` |
|----------|--------|--------|--------|
| **Windows (ORT)** | ONNX Runtime CPU EP | ONNX Runtime DML EP | ONNX Runtime DML EP (MCDM devices) |
| **Windows (non-ORT)** | TFLite/XNNPACK | DirectML | DirectML |
| **macOS (Apple Silicon, ≥14.4)** | CoreML (CPUOnly) | CoreML (CPUAndGPU) | CoreML (CPUAndNeuralEngine) |
| **macOS (Intel or <14.4)** | TFLite/XNNPACK | TFLite fallback | Not supported |
| **ChromeOS** | TFLite/XNNPACK | ChromeML GPU delegate | CPU fallback |
| **Linux** | TFLite/XNNPACK | CPU fallback | Not supported |
| **Android** | TFLite/XNNPACK | TFLite OpenCL delegate | TFLite NNAPI delegate |

##### DML Backend Details (`services/webnn/dml/`)

On Windows, the DML (DirectML) backend uses:

```
services/webnn/dml/
  platform_functions.h       ← Loads D3D12, DirectML, DXCore functions
  adapter.h/cc               ← GPU/NPU adapter enumeration
  graph_impl_dml.h/cc        ← Graph compilation and execution
  context_impl_dml.h/cc      ← DML context management
```

Key function loads from `platform_functions.h`:
- `D3D12CreateDevice` — for GPU device creation
- `DMLCreateDevice1` — for DirectML device creation  
- `DXCoreCreateAdapterFactory` — for NPU/MCDM device enumeration (NPU devices aren't visible through traditional DXGI)

##### ORT Backend Details (`services/webnn/ort/`)

```
services/webnn/ort/
  context_impl_ort.h/cc          ← ORT context with EP selection
  context_provider_ort.h/cc      ← ORT context provider
  graph_impl_ort.h/cc            ← ONNX graph building
  graph_builder_ort.h/cc         ← WebNN op → ONNX op mapping
  tensor_impl_ort.h/cc           ← Tensor management
  environment.h/cc               ← ORT Environment singleton
  ort_session_options.h/cc       ← EP configuration
```

##### TFLite Backend Details (`services/webnn/tflite/`)

```
services/webnn/tflite/
  context_impl_tflite.h/cc       ← TFLite context
  context_impl_litert.h/cc       ← LiteRT context (newer)
  graph_impl_tflite.h/cc         ← TFLite graph execution
  graph_impl_litert.h/cc         ← LiteRT graph execution
  graph_builder_tflite.h/cc      ← WebNN op → TFLite op mapping
  tensor_impl_tflite.h/cc        ← Tensor management
```

##### CoreML Backend Details (`services/webnn/coreml/`)

```
services/webnn/coreml/
  context_impl_coreml.h/cc       ← CoreML context (macOS/iOS)
  graph_impl_coreml.h/cc         ← Core ML model compilation
  graph_builder_coreml.h/cc      ← WebNN op → CoreML op mapping
```

#### B. On-Device AI (Gemini Nano) Backend Selection

The ChromeML shared library handles backend selection for Gemini Nano inference.

##### `ModelBackendType` Enum

```cpp
// services/on_device_model/ml/chrome_ml_types.h
enum class ModelBackendType {
  kGpuBackend,    // Default WebGPU-accelerated backend (uses Dawn internally)
  kApuBackend,    // APU accelerator backend (special hardware + model files)
  kCpuBackend,    // CPU backend
};
```

##### `ModelPerformanceHint` Enum

```cpp
// services/on_device_model/ml/chrome_ml_types.h
enum class ModelPerformanceHint {
  kHighestQuality,
  kFastestInference,
};
```

##### GPU Performance Estimation

Before selecting a backend, Chrome estimates GPU performance:

```cpp
// chrome_ml_api.h
bool (*GetEstimatedPerformance)(ChromeMLPerformanceInfo* performance_info);

struct ChromeMLPerformanceInfo {
  float input_speed;          // Estimated tokens/second for prefill
  float output_speed;         // Estimated tokens/second for decode
  bool is_integrated_gpu;
  uint64_t device_heap_size;  // GPU memory
  uint64_t max_buffer_size;
};
```

The `GetEstimatedPerformance()` function runs a benchmark shader on the GPU (via Dawn/WebGPU internally) and reports throughput. Based on these numbers, Chrome decides:
- **GPU path** (default): If the GPU meets performance thresholds
- **CPU fallback**: If GPU is inadequate but CPU requirements are met
- **Not available**: If neither meets minimum requirements

##### GPU Blocklist

```
services/on_device_model/ml/gpu_blocklist.cc
```

Certain GPU vendor/device combinations are blocklisted due to crashes or poor performance. The `GpuConfig` struct carries identification:

```cpp
struct GpuConfig {
  uint32_t vendor_id;
  uint32_t device_id;
  const char* architecture;
  const char* driver_description;
  WGPUAdapterType adapter_type;
  WGPUBackendType backend_type;
};
```

##### APU Backend

The APU (Accelerated Processing Unit) backend is a specialized path for hardware with dedicated AI accelerators. It differs from the GPU path:
- Requires special model files with separate sentencepiece tokenizer
- Uses `model_path` instead of `weights_file`
- Only available on specific hardware

##### Model Descriptor Configuration

```cpp
struct ChromeMLModelDescriptor {
  ModelBackendType backend_type;      // GPU / CPU / APU
  const ChromeMLModelData* model_data;
  uint32_t max_tokens;
  float temperature;
  int top_k;
  int num_draft_tokens;               // Speculative decoding
  bool prefer_texture_weights;
  bool enable_host_mapped_pointer;
  bool use_low_power;
  bool allow_fp16;
  ModelPerformanceHint performance_hint;
  const uint32_t* adaptation_ranks;
  size_t adaptation_ranks_size;
};
```

---

## 5. Prompt API Model Provisioning

### API Surface

The Prompt API (also known as the Built-in AI APIs) is exposed via:

```javascript
// Primary entry point
const session = await LanguageModel.create(options);

// Other built-in APIs using the same model infrastructure:
const summarizer = await Summarizer.create(options);
const writer = await Writer.create(options);
const rewriter = await Rewriter.create(options);
const proofreader = await Proofreader.create(options);
```

### Source Files

```
chrome/browser/ai/
  ai_manager.h/cc                        ← AIManager: central coordinator
  ai_language_model.h/cc                 ← LanguageModel implementation
  ai_summarizer.h/cc                     ← Summarizer implementation
  ai_writer.h/cc                         ← Writer implementation  
  ai_rewriter.h/cc                       ← Rewriter implementation
  ai_proofreader.h/cc                    ← Proofreader implementation
  ai_classifier.h/cc                     ← Classifier implementation
  ai_context_bound_object.h/cc           ← Base for context-bound AI objects
  ai_context_bound_object_set.h/cc       ← Manages object lifetimes
  ai_on_device_session.h/cc              ← On-device session wrapper
  ai_data_keyed_service.h/cc             ← Per-profile AI data service
  ai_data_keyed_service_factory.h/cc     ← Factory for AI data service
  ai_utils.h/cc                          ← Shared utilities
  features.h/cc                          ← Feature flags
```

### Model Availability States

```javascript
const availability = await LanguageModel.availability();
// Returns one of:
// "unavailable"   — device lacks sufficient power or disk space
// "downloadable"  — model can be downloaded but hasn't been yet
// "downloading"   — download is in progress
// "available"     — model is ready, session can be created immediately
```

### Provisioning Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  JavaScript: LanguageModel.create()                             │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Blink Renderer: ai::AILanguageModel                            │
│  → Mojo IPC to browser process                                  │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  Browser Process: AIManager                                     │
│  1. Check model availability via OptimizationGuideKeyedService  │
│  2. If not downloaded: trigger Component Updater download       │
│  3. Wait for model to be ready                                  │
│  4. Create ODM (On-Device Model) session                        │
└──────────────────────┬──────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  OptimizationGuideKeyedService                                  │
│  → OnDeviceModelComponentStateManager                           │
│  → OptimizationGuideOnDeviceModelInstallerPolicy                │
│  → Component Updater (Omaha protocol → CDN download)            │
└──────────────────────┬──────────────────────────────────────────┘
                       │ (model ready)
                       ▼
┌─────────────────────────────────────────────────────────────────┐
│  OnDeviceModelService (Mojo service, sandboxed process)         │
│  → ml::BackendImpl → ChromeML shared library                   │
│  → OnDeviceModelExecutor → ChromeMLModel + ChromeMLSession     │
└─────────────────────────────────────────────────────────────────┘
```

### Session Creation Details

When `LanguageModel.create()` is called and the model is available:

1. `AIManager` requests a session from `OnDeviceModelService` via Mojo.
2. `OnDeviceModelService` calls `BackendImpl::CreateWithResult()` with `LoadModelParams` containing the model file path.
3. `OnDeviceModelExecutor::Init()` calls `ChromeMLAPI::SessionCreateModel()` to load the model into the ChromeML library.
4. A `ChromeMLSession` is created via `ChromeMLAPI::CreateSession()`.
5. `SessionImpl` wraps the session with `max_tokens_` and a `SessionAccessor` for thread-safe access.

### Download Progress Monitoring

```javascript
const session = await LanguageModel.create({
  monitor(m) {
    m.addEventListener('downloadprogress', (e) => {
      console.log(`Downloaded ${e.loaded * 100}%`);
    });
  },
});
```

### Session Parameters

```javascript
const session = await LanguageModel.create({
  systemPrompt: "You are a helpful assistant.",
  temperature: 0.7,
  topK: 40,
  // signal: abortController.signal,
});

// Usage
const response = await session.prompt("Hello!");
const stream = session.promptStreaming("Tell me a story.");
```

### Model Lifecycle Events

| Event | What Happens |
|-------|-------------|
| First `create()` call | GPU benchmark runs → model variant selected → download begins |
| Browser startup | Check for model updates |
| Daily | Check for LoRA weight updates |
| Disk space low | Model automatically deleted (even mid-session) |
| 30 days inactive | Model purged |
| Enterprise policy disable | Model purged |
| New model version | Background download → hot-swap |

### Debugging

- **`chrome://on-device-internals`** — Shows model name, version, status, and diagnostic info. Example: "Model Name: v3Nano, Version: 2025.06.30.1229"
- **`chrome://flags/#optimization-guide-on-device-model`** — Enable/disable the on-device model component
- **`chrome://flags/#prompt-api-for-gemini-nano`** — Enable/disable the Prompt API

### Safety Layer

The on-device model service includes a safety subsystem:

```
services/on_device_model/safety/
```

All text output is classified via `ChromeMLSafetyResult`:

```cpp
enum class ChromeMLSafetyResult {
  kOk,
  kNoClassifier,
  kInsufficientStorage,
  kModelExecutionFailure,
};
```

Safety classification runs on a separate `ChromeMLTSModel` (text safety model) loaded via `ChromeMLTSAPI`. The classifier model is a separate component (`kClassifierModel`) downloaded alongside the base model.

---

## Appendix: Key Enum Reference

### WebNN Device Types

```cpp
// services/webnn/public/mojom/webnn_context_provider.mojom
enum Device { kCpu = 0, kGpu = 1, kNpu = 2 };
```

### ChromeML Backend Types

```cpp
// services/on_device_model/ml/chrome_ml_types.h
enum class ModelBackendType {
  kGpuBackend,   // WebGPU/Dawn
  kApuBackend,   // Dedicated AI accelerator
  kCpuBackend,   // CPU
};
```

### ChromeML Performance Hints

```cpp
enum class ModelPerformanceHint {
  kHighestQuality,
  kFastestInference,
};
```

### ChromeML Generation Status

```cpp
enum class ChromeMLGenerateStatus {
  kInProgress,
  kComplete,
  kInvalidConstraint,
};
```

### WebNN Context Backend UMA

```cpp
// services/webnn/webnn_context_impl.h
enum class ContextBackendUma {
  kNotSupported,
  kTfLite,
  kCoreML,
  kDml,
  kOrt,
  kLiteRT,
};
```

### WebNN Feature Flags

```cpp
// services/webnn/public/mojom/features.mojom
kWebNNCoreML       // CoreML backend on Apple platforms
kWebNNLiteRT       // LiteRT backend
kWebNNOnnxRuntime  // ORT backend on Windows
```

---

## Appendix: Directory Map

```
services/webnn/                          ← WebNN graph compute API
  coreml/                                ← Apple CoreML backend
  dml/                                   ← Windows DirectML backend
  ort/                                   ← Windows ONNX Runtime backend
  tflite/                                ← TFLite + LiteRT backend (Linux, Android, fallback)
  host/                                  ← Host-side utilities
  public/                                ← Mojom interfaces and shared types
  webnn_context_provider_impl.cc         ← Backend selection logic

services/on_device_model/                ← On-device LLM service (Gemini Nano)
  ml/                                    ← ChromeML shared library interface
    chrome_ml.h                          ← Library loader
    chrome_ml_api.h                      ← C API function table
    chrome_ml_types.h                    ← ModelBackendType, InputPiece enums
    on_device_model_executor.h           ← Session/model management
    session_accessor.h                   ← Thread-safe session access
    gpu_blocklist.cc                     ← GPU blocklist
    constraint_factory.h                 ← Constrained decoding
    ts_model.h                           ← Text safety model
  android/                               ← Android AiCore backend
  fake/                                   ← Fake backend for testing
  safety/                                 ← Safety classification
  public/                                 ← Mojom interfaces
  backend.h                               ← Backend abstraction
  backend_model.h                         ← BackendModel interface
  backend_session.h                       ← BackendSession interface

chrome/browser/ai/                       ← Built-in AI APIs (Prompt, Summarizer, etc.)
  ai_manager.h/cc                        ← Central coordinator
  ai_language_model.h/cc                 ← LanguageModel.create() impl
  ai_summarizer.h/cc                     ← Summarizer impl
  ai_writer.h/cc                         ← Writer impl
  ai_rewriter.h/cc                       ← Rewriter impl
  ai_proofreader.h/cc                    ← Proofreader impl
  ai_on_device_session.h/cc              ← Session wrapper

chrome/browser/component_updater/
  optimization_guide_on_device_model_installer.h/cc  ← Model download

components/optimization_guide/           ← Optimization guide framework
  core/                                  ← Core optimization guide logic

chrome/browser/optimization_guide/
  optimization_guide_keyed_service.h/cc  ← Per-profile service
```

---
