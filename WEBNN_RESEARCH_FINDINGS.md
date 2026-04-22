# WebNN Ecosystem Research Findings

> Research compiled April 22, 2026

---

## Table of Contents

1. [WebNN API Specification](#1-webnn-api-specification)
2. [ONNX Runtime Web with WebNN Backend](#2-onnx-runtime-web-with-webnn-backend)
3. [Google LiteRT.js WebNN Support](#3-google-litertjs-formerly-tensorflow-lite-webnn-support)
4. [Direct WebNN API Usage (navigator.ml)](#4-direct-webnn-api-usage-navigatorml)

---

## 1. WebNN API Specification

**Source:** [W3C Editor's Draft, 27 March 2026](https://webmachinelearning.github.io/webnn/)
**Status:** W3C Candidate Recommendation (CR Snapshot 22 January 2026)
**Working Group:** [Web Machine Learning Working Group](https://www.w3.org/groups/wg/webmachinelearning)
**Editors:** Ningxin Hu (Intel), Dwayne Robinson (Microsoft)

### 1.1 What It Provides

The WebNN API is a **dedicated low-level API for neural network inference hardware acceleration**. It provides a web-friendly, hardware-agnostic abstraction layer that leverages ML capabilities of operating systems and underlying hardware platforms (GPUs, CPUs, NPUs/AI accelerators) without being tied to platform-specific APIs.

Key design goals:
- **Privacy-preserving**: All computation runs on-device; input data never leaves the browser sandbox.
- **Hardware-agnostic**: Works across GPUs, CPUs, and dedicated ML accelerators via OS-level backends.
- **Framework-friendly**: Designed to be consumed by JS ML frameworks (ONNX Runtime Web, LiteRT.js) while also being directly usable by developers.
- **Interoperable**: Integrates with WebGPU (`GPUDevice`-backed contexts) and media APIs for real-time pipelines.

### 1.2 Core Architecture

The API is built around four key interfaces:

| Interface | Role |
|-----------|------|
| `navigator.ml` (`ML`) | Entry point. Provides `createContext()` to obtain an `MLContext`. |
| `MLContext` | Represents a device-bound execution context. Manages tensor lifecycle and graph dispatch. |
| `MLGraphBuilder` | Graph construction API. Provides ~95 operations to build computational graphs. |
| `MLGraph` | A compiled, immutable computational graph ready for execution. |
| `MLTensor` | Opaque device-specific tensor storage for efficient I/O binding. |
| `MLOperand` | Represents an intermediate value (node) in the computation graph during construction. |

### 1.3 How MLContext / MLGraphBuilder API Works

#### Step 1: Create an MLContext

```javascript
// Option A: Preference-based (implementation picks the best device)
const context = await navigator.ml.createContext({
  devicePreference: 'gpu',        // 'cpu' | 'gpu' | 'npu'
  powerPreference: 'high-performance' // 'default' | 'low-power' | 'high-performance'
});

// Option B: WebGPU interop (backed by a GPUDevice)
const gpuDevice = await gpuAdapter.requestDevice();
const context = await navigator.ml.createContext(gpuDevice);
```

The `devicePreference` is a **hint** only — the implementation may choose a different device. This is intentional for security (prevents targeting specific hardware) and for portability.

#### Step 2: Build a Computation Graph

```javascript
const builder = new MLGraphBuilder(context);

// Declare inputs
const input = builder.input('input', {
  dataType: 'float32',
  dimensions: [1, 3, 224, 224]
});

// Declare constants (weights, biases)
const weights = builder.constant(
  { dataType: 'float32', dimensions: [32, 3, 3, 3] },
  weightsArrayBuffer
);
const bias = builder.constant(
  { dataType: 'float32', dimensions: [32] },
  biasArrayBuffer
);

// Build operations
const conv = builder.conv2d(input, weights, { padding: [1, 1, 1, 1] });
const added = builder.add(conv, bias);
const activated = builder.relu(added);
const pooled = builder.averagePool2d(activated, {
  windowDimensions: [7, 7],
  layout: 'nchw'
});
const reshaped = builder.reshape(pooled, [1, 32]);
const output = builder.softmax(reshaped);

// Compile the graph
const graph = await builder.build({ 'output': output });
```

Note: `MLGraphBuilder` is a **data definition API** — it constructs a graph description but does not execute anything. Execution only happens at `dispatch()`.

#### Step 3: Create Tensors, Dispatch, and Read Results

```javascript
// Create input tensor
const inputTensor = await context.createTensor({
  dataType: 'float32',
  shape: [1, 3, 224, 224],
  writable: true
});

// Create output tensor
const outputTensor = await context.createTensor({
  dataType: 'float32',
  shape: [1, 32],
  readable: true
});

// Write data (non-blocking, queued on context timeline)
context.writeTensor(inputTensor, inputData);

// Dispatch graph execution (queued after write)
context.dispatch(graph,
  { 'input': inputTensor },
  { 'output': outputTensor }
);

// Read results (awaits all queued operations)
const resultBuffer = await context.readTensor(outputTensor);
const results = new Float32Array(resultBuffer);

// Clean up
inputTensor.destroy();
outputTensor.destroy();
```

**Timeline ordering**: All operations (`writeTensor`, `dispatch`, `readTensor`) posted to an `MLContext` execute in order. No manual synchronization is needed.

### 1.4 Supported Operations (~95 total)

The `MLGraphBuilder` provides approximately 95 operations:

| Category | Operations |
|----------|-----------|
| **Element-wise Unary** | `abs`, `ceil`, `cos`, `erf`, `exp`, `floor`, `identity`, `log`, `neg`, `reciprocal`, `sign`, `sin`, `sqrt`, `tan`, `tanh` |
| **Element-wise Binary** | `add`, `div`, `max`, `min`, `mul`, `pow`, `sub` |
| **Activation Functions** | `elu`, `gelu`, `hardSigmoid`, `hardSwish`, `leakyRelu`, `linear`, `prelu`, `relu`, `sigmoid`, `softmax`, `softplus`, `softsign` |
| **Comparison/Logical** | `equal`, `greater`, `greaterOrEqual`, `lesser`, `lesserOrEqual`, `logicalAnd`, `logicalNot`, `logicalOr`, `logicalXor`, `not` |
| **Convolution** | `conv2d`, `convTranspose2d` |
| **Normalization** | `batchNormalization`, `instanceNormalization`, `layerNormalization` |
| **Pooling** | `averagePool2d`, `l2Pool2d`, `maxPool2d` |
| **Reduction** | `reduceL1`, `reduceL2`, `reduceLogSum`, `reduceLogSumExp`, `reduceMax`, `reduceMean`, `reduceMin`, `reduceProduct`, `reduceSum`, `reduceSumSquare` |
| **Tensor Manipulation** | `cast`, `clamp`, `concat`, `expand`, `gather`, `gatherElements`, `gatherND`, `pad`, `reshape`, `resample2d`, `reverse`, `scatterElements`, `scatterND`, `slice`, `split`, `tile`, `transpose`, `triangular`, `where` |
| **Linear Algebra** | `gemm`, `matmul` |
| **Recurrent** | `gru`, `gruCell`, `lstm`, `lstmCell` |
| **Quantization** | `dequantizeLinear`, `quantizeLinear` |
| **Other** | `argMax`, `argMin`, `cumulativeSum` |
| **Graph construction** | `input()`, `constant()`, `build()` |

### 1.5 Key Additions Since CR 2024

Between the April 2024 and January 2026 CR snapshots, the spec underwent **100+ significant changes**:

- **Third wave of operators** for enhanced transformer support
- **`MLTensor` API** for device-specific buffer sharing (replaces earlier `MLBuffer` concept)
- **New abstract device selection** mechanism (hint-based, not enumeration)
- **`dispatch()` method** replaces deprecated `compute()` for graph execution
- **`opSupportLimits()`** API for querying operator support without side-channel inference
- **WebGPU interop** via `MLTensor` export (`exportToGPU`)
- Strengthened **security and privacy** considerations including fingerprinting mitigations

### 1.6 Permissions Policy

WebNN is gated by a permissions policy: `"webnn"`. It is **disabled by default in cross-origin iframes**. The embedding page must explicitly grant permission:

```html
<iframe src="..." allow="webnn"></iframe>
```

---

## 2. ONNX Runtime Web with WebNN Backend

### 2.1 Overview

ONNX Runtime Web (`onnxruntime-web`) is Microsoft's JavaScript library for running ONNX models in browsers and Node.js. It supports WebNN as an **execution provider (EP)**, alongside WebAssembly (WASM) and WebGPU.

**npm package:** `onnxruntime-web`
**Current version:** Actively maintained (nightly builds via `onnxruntime-web@dev`)
**Documentation:** [onnxruntime.ai/docs/tutorials/web/ep-webnn.html](https://onnxruntime.ai/docs/tutorials/web/ep-webnn.html)

### 2.2 Installation

```bash
npm install onnxruntime-web
```

### 2.3 API for Using WebNN Execution Provider

#### Import the "all" bundle

The standard `onnxruntime-web` entry point does **not** include WebNN. You must import the `all` bundle:

```javascript
// ES module
import * as ort from 'onnxruntime-web/all';

// HTML script tag
// <script src="path/to/ort.all.min.js"></script>
```

#### Create an Inference Session with WebNN EP

```javascript
const session = await ort.InferenceSession.create('./model.onnx', {
  executionProviders: [
    {
      name: 'webnn',
      deviceType: 'gpu',              // 'cpu' | 'gpu' | 'npu'
      powerPreference: 'default',     // 'default' | 'low-power' | 'high-performance'
    }
  ]
});
```

#### Run Inference

```javascript
const inputTensor = new ort.Tensor('float32', inputData, [1, 3, 224, 224]);
const feeds = { 'input': inputTensor };
const results = await session.run(feeds);

console.log(results['output'].data);
```

### 2.4 WebNN EP Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | `string` | — | Must be `'webnn'` |
| `deviceType` | `'cpu' \| 'gpu' \| 'npu'` | `'cpu'` | Preferred hardware device |
| `powerPreference` | `'default' \| 'low-power' \| 'high-performance'` | `'default'` | Power consumption preference |
| `context` | `MLContext` | — | Pass a pre-created `MLContext` (required for IO binding) |

### 2.5 Advanced: IO Binding with MLTensor

For high-performance scenarios (especially transformer models with iterative inference), you can keep tensor data on the WebNN device to avoid CPU round-trips:

```javascript
// Create a shared MLContext
const mlContext = await navigator.ml.createContext({ deviceType: 'gpu' });

// Create session with the shared context
const session = await ort.InferenceSession.create('./model.onnx', {
  executionProviders: [{
    name: 'webnn',
    deviceType: 'gpu',
    context: mlContext,
  }],
  preferredOutputLocation: 'ml-tensor'
});

// Create an MLTensor for input
const inputMLTensor = await mlContext.createTensor({
  dataType: 'float32',
  shape: [1, 3, 224, 224],
  writable: true,
});
mlContext.writeTensor(inputMLTensor, inputArrayBuffer);

// Wrap as ORT tensor
const inputTensor = ort.Tensor.fromMLTensor(inputMLTensor, {
  dataType: 'float32',
  dims: [1, 3, 224, 224],
});

// Run inference — output stays on device
const results = await session.run({ 'input': inputTensor });

// Read output back to CPU when needed
const outputData = await results['output'].getData();
console.log(new Float32Array(outputData));

// Clean up
inputMLTensor.destroy();
results['output'].dispose();
```

### 2.6 Operator Fallback

If the WebNN EP does not support a particular ONNX operator, it **automatically falls back to the WASM EP** for that operator. This means most ONNX models will run even if WebNN doesn't cover every op — only the supported ops are accelerated.

### 2.7 Maturity Assessment

| Aspect | Status |
|--------|--------|
| npm package | Stable (`onnxruntime-web`) |
| WebNN EP | Production-ready in nightly builds; actively developed |
| Operator coverage | Extensive but not 100% of ONNX ops; see [webnn-operators.md](https://github.com/microsoft/onnxruntime/blob/main/js/web/docs/webnn-operators.md) |
| IO Binding (MLTensor) | Supported since late 2025 |
| Platform support | Chrome/Edge on Windows (via ONNX Runtime/Windows ML), macOS (Core ML), Linux (TFLite/XNNPACK) |
| Browser requirement | Chromium-based; may require `--enable-features=WebMachineLearningNeuralNetwork` flag |

ONNX Runtime Web is the **most mature** framework for consuming WebNN. Microsoft actively co-develops both the WebNN spec and the ONNX Runtime WebNN EP.

---

## 3. Google LiteRT.js (formerly TensorFlow Lite) WebNN Support

### 3.1 Background

Google renamed TensorFlow Lite to **LiteRT** (Lite Runtime) and released **LiteRT.js** as the web runtime. It runs `.tflite` models in the browser with hardware acceleration.

**npm package:** `@litertjs/core`
**Current version:** 2.4.0 (published March 29, 2026)
**Docs:** [ai.google.dev/edge/litert/web](https://ai.google.dev/edge/litert/web)

### 3.2 Current Capabilities

LiteRT.js currently supports two acceleration backends:
- **WebGPU** — GPU-accelerated inference (primary high-performance path)
- **CPU (XNNPack via WebAssembly)** — works on any browser

```typescript
import { loadLiteRt, loadAndCompile, Tensor } from '@litertjs/core';

await loadLiteRt('/path/to/wasm/directory/');

const model = await loadAndCompile(
  '/path/to/model.tflite',
  { accelerator: 'webgpu' }  // or 'cpu'
);

const inputTensor = new Tensor(new Float32Array(1 * 3 * 224 * 224), [1, 3, 224, 224]);
const gpuTensor = await inputTensor.moveTo('webgpu');

const results = model.run(gpuTensor);
gpuTensor.delete();

const cpuResult = results[0].moveTo('wasm');
console.log(cpuResult.toTypedArray());
cpuResult.delete();
```

### 3.3 WebNN Support Status

**Status: "Coming soon" / Work in progress**

- The [WebNN implementation status page](https://webmachinelearning.github.io/webnn-status/) lists LiteRT.js as an **External Delegate** integration, with operations being tracked for support.
- A Chromium blink-dev discussion confirmed that **LiteRT.js is working on WebNN support**.
- The reference video ([youtu.be/HAjotVloAvI?t=219](https://youtu.be/HAjotVloAvI?t=219)) from a Google I/O or Chrome Dev Summit presentation announced the intention to add WebNN as a delegate backend.
- A GitHub Actions run titled **"Exposing WebNN Options to LiteRT.js user #7600"** was found in the LiteRT repository, indicating active development.

**What's NOT available yet:**
- No `{ accelerator: 'webnn' }` option in `@litertjs/core` as of v2.4.0
- No separate WebNN delegate npm package for LiteRT.js
- The legacy `webnn-tflite-delegate` npm package (last published ~4 years ago) is for Node.js (`tfjs-tflite-node`) and is **not** related to the modern LiteRT.js browser runtime

### 3.4 Chromium Backend Integration

Interestingly, **Chromium itself uses LiteRT (TFLite) as a backend for the WebNN API** on multiple platforms:

| Platform | WebNN uses LiteRT internally? |
|----------|------------------------------|
| ChromeOS | Yes — TFLite + XNNPACK for CPU; Chrome ML GPU delegate for GPU |
| Linux | Yes — TFLite + XNNPACK (CPU only) |
| Android | Yes — TFLite + XNNPACK (CPU), OpenCL (GPU), NNAPI (NPU) |
| Windows | TFLite as fallback when ONNX Runtime/DirectML features are off |
| macOS (Intel) | TFLite as fallback when Core ML is unavailable |

This means LiteRT/TFLite is deeply embedded in the WebNN stack at the browser level, even though the LiteRT.js JavaScript API doesn't yet expose WebNN as a user-facing accelerator option.

### 3.5 Summary

| Aspect | Status |
|--------|--------|
| npm package | `@litertjs/core` v2.4.0 |
| WebGPU acceleration | Supported and production-ready |
| CPU (XNNPack) acceleration | Supported |
| WebNN acceleration | Not yet available in the JS API; under active development |
| Expected integration | WebNN as an additional accelerator option alongside `'webgpu'` and `'cpu'` |

---

## 4. Direct WebNN API Usage (navigator.ml)

### 4.1 Browser Support Status

WebNN is primarily supported in **Chromium-based browsers** (Chrome, Edge, Opera, Vivaldi, Brave).

| Interface / Method | Chromium Version |
|-------------------|-----------------|
| `navigator.ml` | M112 |
| `ML.createContext()` | M112 |
| `MLContext.dispatch()` | M128 |
| `MLContext.createTensor()` | M129 |
| `MLContext.readTensor()` | M129 |
| `MLContext.writeTensor()` | M129 |
| `MLContext.opSupportLimits()` | M128 |
| `MLGraph` | M112 |
| `MLGraphBuilder` (constructor + operators) | M112 |
| `MLTensor` | M124 |
| `MLOperand.MLNumber` | M132 |

**Platform-specific backends:**

| Platform | CPU Backend | GPU Backend | NPU Backend |
|----------|------------|------------|-------------|
| **Windows 11 24H2+** | ONNX Runtime (Windows ML) | ONNX Runtime (GPU EP) | ONNX Runtime (NPU EP) |
| **Windows (default)** | TFLite + XNNPACK | DirectML (if flag on) | DirectML (if hardware available) |
| **macOS (Apple Silicon, ≥14.4)** | Core ML (CPUOnly) | Core ML (CPUAndGPU) | Core ML (CPUAndNeuralEngine) |
| **macOS Intel / <14.4** | TFLite + XNNPACK | TFLite (fallback) | TFLite (fallback) |
| **ChromeOS** | TFLite + XNNPACK | Chrome ML GPU / OpenCL | Falls back to CPU |
| **Linux** | TFLite + XNNPACK | Falls back to CPU | Not supported |
| **Android** | TFLite + XNNPACK | TFLite OpenCL delegate | TFLite NNAPI delegate |

**Firefox / Safari:** No WebNN support. No announced plans.

**Flags that may be needed:**
- `--enable-features=WebMachineLearningNeuralNetwork` (general enable)
- `kWebNNOnnxRuntime` (Windows, for ONNX Runtime backend)
- `kWebNNCoreML` (macOS, for Core ML backend)

A **WebNN Origin Trial** is in progress, allowing developers to sign up for trial keys to test the API in production without requiring user-side flags.

### 4.2 How to Build a Computation Graph

#### Complete Example: Simple Math Graph

```javascript
// Check for WebNN support
if (!('ml' in navigator)) {
  throw new Error('WebNN is not supported in this browser');
}

// Create context
const context = await navigator.ml.createContext({
  devicePreference: 'gpu'
});

// Build graph
const builder = new MLGraphBuilder(context);

const TENSOR_DIMS = [1, 2, 2, 2];
const TENSOR_SIZE = 8;

const desc = { dataType: 'float32', dimensions: TENSOR_DIMS };

// Constants
const constant1 = builder.constant(desc, new Float32Array(TENSOR_SIZE).fill(0.5));
const constant2 = builder.constant(desc, new Float32Array(TENSOR_SIZE).fill(0.5));

// Inputs (values bound at dispatch time)
const input1 = builder.input('input1', desc);
const input2 = builder.input('input2', desc);

// Operations: output = (constant1 + input1) * (constant2 + input2)
const intermediateOutput1 = builder.add(constant1, input1);
const intermediateOutput2 = builder.add(constant2, input2);
const output = builder.mul(intermediateOutput1, intermediateOutput2);

// Compile
const graph = await builder.build({ 'output': output });
```

#### Complete Example: Neural Network Layer (Conv2D + ReLU)

```javascript
const context = await navigator.ml.createContext({ devicePreference: 'gpu' });
const builder = new MLGraphBuilder(context);

// Input: batch=1, channels=3, height=224, width=224
const input = builder.input('image', {
  dataType: 'float32',
  dimensions: [1, 3, 224, 224]
});

// Conv2D weights: 16 output channels, 3 input channels, 3x3 kernel
const convWeights = builder.constant(
  { dataType: 'float32', dimensions: [16, 3, 3, 3] },
  new Float32Array(16 * 3 * 3 * 3)  // would be loaded from a model
);

const convBias = builder.constant(
  { dataType: 'float32', dimensions: [16] },
  new Float32Array(16)
);

// Conv2D → Add bias → ReLU → Global Average Pool → Softmax
const conv = builder.conv2d(input, convWeights, {
  padding: [1, 1, 1, 1],
  strides: [1, 1],
  inputLayout: 'nchw',
  filterLayout: 'oihw'
});
const biased = builder.add(conv, builder.reshape(convBias, [1, 16, 1, 1]));
const activated = builder.relu(biased);
const pooled = builder.averagePool2d(activated, {
  windowDimensions: [224, 224],
  layout: 'nchw'
});
const flattened = builder.reshape(pooled, [1, 16]);
const output = builder.softmax(flattened);

const graph = await builder.build({ 'result': output });
```

### 4.3 How to Dispatch Compute

The modern WebNN API uses `MLTensor` + `dispatch()` (the `compute()` method is **deprecated**).

```javascript
// Create tensors on the context
const inputTensor = await context.createTensor({
  dataType: 'float32',
  shape: [1, 3, 224, 224],
  writable: true     // we will write data into this tensor
});

const outputTensor = await context.createTensor({
  dataType: 'float32',
  shape: [1, 16],
  readable: true     // we will read data from this tensor
});

// Write input data (non-blocking — queued on context timeline)
const imageData = new Float32Array(1 * 3 * 224 * 224);
// ... fill imageData from canvas, video frame, etc.
context.writeTensor(inputTensor, imageData);

// Dispatch graph execution (non-blocking — queued after write)
context.dispatch(graph,
  { 'image': inputTensor },
  { 'result': outputTensor }
);

// Read output (returns Promise, resolves after dispatch completes)
const resultBuffer = await context.readTensor(outputTensor);
const probabilities = new Float32Array(resultBuffer);
console.log('Prediction:', probabilities);

// Clean up
inputTensor.destroy();
outputTensor.destroy();
```

#### Chained Inference (Iterative Models / Transformers)

```javascript
// Reuse tensors across multiple dispatch calls
for (let step = 0; step < maxSteps; step++) {
  // Write new input for this step
  context.writeTensor(inputTensor, getInputForStep(step));

  // Dispatch — automatically waits for writeTensor to complete
  context.dispatch(graph,
    { 'input': inputTensor },
    { 'output': outputTensor }
  );
}

// Read final output after all steps
const finalResult = await context.readTensor(outputTensor);
```

### 4.4 Feature Detection Pattern

```javascript
async function getWebNNContext(preferences = {}) {
  if (!('ml' in navigator)) {
    console.warn('WebNN not available. Falling back to WASM.');
    return null;
  }

  try {
    const context = await navigator.ml.createContext({
      devicePreference: preferences.device || 'gpu',
      powerPreference: preferences.power || 'default'
    });
    console.log('WebNN context created successfully');
    return context;
  } catch (e) {
    console.warn('Failed to create WebNN context:', e);
    return null;
  }
}
```

### 4.5 WebGPU Interop

`MLTensor` can be exported to a WebGPU `GPUBuffer` for zero-copy or efficient sharing:

```javascript
// Create context backed by a GPUDevice
const gpuAdapter = await navigator.gpu.requestAdapter();
const gpuDevice = await gpuAdapter.requestDevice();
const context = await navigator.ml.createContext(gpuDevice);

// After dispatch, export tensor to WebGPU for rendering
const gpuBuffer = await context.exportToGPU(outputTensor);
// Use gpuBuffer in a WebGPU render pipeline...
```

---

## Summary Comparison

| Feature | Direct WebNN API | ONNX Runtime Web | LiteRT.js |
|---------|-----------------|-------------------|-----------|
| **npm package** | Browser built-in | `onnxruntime-web` | `@litertjs/core` |
| **WebNN support** | Native API | Via `'webnn'` EP | Coming soon |
| **Model format** | Manual graph construction | `.onnx` files | `.tflite` files |
| **Fallback** | None (manual) | Auto-fallback to WASM | WebGPU / CPU |
| **Maturity** | CR spec, shipping in Chromium | Production-ready | WebNN not yet available |
| **Best for** | Custom ops, low-level control | Running pre-trained ONNX models | Running TFLite/PyTorch-converted models |
| **Browser support** | Chromium M112+ | Chromium M112+ | Any modern browser (WebGPU) |
| **NPU access** | Yes (via device hint) | Yes (via `deviceType: 'npu'`) | Not yet via WebNN |
