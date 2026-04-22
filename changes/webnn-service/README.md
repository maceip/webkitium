# WebNN Service Change

This change lane owns the WebNN (`navigator.ml`) integration work.

See `DESIGN.md` for the platform backend runtime map.
See `docs/WEBNN_PROGRAM.md` for milestones and acceptance criteria.

## Scope

Allowed here:

- Platform-specific WebKit patches required for the WebNN service.
- Cross-platform WebKit interface patches required by the ML context and graph
  builder boundaries.
- Runtime validation changes that prove `navigator.ml.createContext()` succeeds.

Not allowed here:

- Auth/passkey work.
- Extension shim work.
- Generic platform compiler or dependency fixes.
- WebGPU-only changes (use the `windows-webgpu-service` lane).

## Platform Backends

| Platform | ML backend | Library | Status |
|----------|-----------|---------|--------|
| Windows | ONNX Runtime | `onnxruntime.dll` | Phase A (lead) |
| macOS | Core ML | `CoreML.framework` | Future |
| Linux | TFLite + XNNPACK | `libtensorflowlite.so` | Future |
| Android | TFLite + XNNPACK / NNAPI | `libtensorflowlite_jni.so` | Future |
| iOS | Core ML | `CoreML.framework` | Future |

## Build Wiring

For Windows (lead platform):

```bash
NG_WINDOWS_ENABLE_WEBNN=1 \
NG_WINDOWS_ENABLE_WEBGPU=1 \
./run-build.sh windows <build-id>
```

CMake requirements:
- `ENABLE_WEBNN:BOOL=ON`
- `FindONNXRuntime.cmake` resolves vcpkg `onnxruntime` or system install.
- ONNX Runtime DLLs present beside `MiniBrowser.exe`.
- Windows-only WebNN source files appended from `PlatformWin.cmake` when
  `ENABLE_WEBNN` is on.

## Integration With WebGPU

WebNN and WebGPU are complementary. The `MLTensor` API supports export to
`GPUBuffer` for zero-copy interop. This means an inference result from WebNN
can be rendered directly by a WebGPU pipeline without CPU round-trip.

For this interop to work, both `ENABLE_WEBGPU` and `ENABLE_WEBNN` must be on,
and the WebNN context must be created with a `GPUDevice`:

```javascript
const gpuDevice = await navigator.gpu.requestAdapter()
  .then(a => a.requestDevice());
const mlContext = await navigator.ml.createContext(gpuDevice);
```

## Acceptance

The build is not accepted from compile success alone. Milestone definitions
and exit criteria are in `docs/WEBNN_PROGRAM.md`.

Minimum lane harness checks:

- `ENABLE_WEBNN:BOOL=ON` in `CMakeCache.txt`.
- ONNX Runtime DLLs present and loadable beside MiniBrowser.
- MiniBrowser launches.
- Runtime probe reports `navigator.ml !== undefined`.
- Runtime probe reports a non-null context from
  `navigator.ml.createContext()`.
- Manifest and validation artifacts uploaded by the standard harness.

## Patch Layout

```text
changes/webnn-service/patches/common
changes/webnn-service/patches/windows
changes/webnn-service/patches/macos
changes/webnn-service/patches/linux
changes/webnn-service/patches/android
changes/webnn-service/patches/ios
```

Keep patch numbering ordered within each directory.

---
