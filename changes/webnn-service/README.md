# WebNN Service Change

This change lane owns the WebNN (`navigator.ml`) integration work, using
**LiteRT-LM** as the unified C++ inference backend across all platforms.

See `DESIGN.md` for the LiteRT-LM runtime architecture.
See `docs/WEBNN_PROGRAM.md` for milestones and acceptance criteria.

## Scope

Allowed here:

- Cross-platform WebKit patches required for the ML context and graph builder
  boundaries.
- Platform-specific patches where LiteRT-LM needs platform hooks (e.g. GPU
  delegate loading).
- Runtime validation changes that prove `navigator.ml.createContext()` succeeds.

Not allowed here:

- Auth/passkey work.
- Extension shim work.
- Generic platform compiler or dependency fixes.
- WebGPU-only changes (use the `windows-webgpu-service` lane).

## Backend: LiteRT-LM

LiteRT-LM (v0.10.2) is Google's production-ready C++ inference framework,
successor to TFLite. It already powers on-device GenAI in Chrome and
Chromebook Plus.

| Platform | Hardware acceleration | Backend delegate |
|----------|---------------------|-----------------|
| Windows | CPU (XNNPACK), GPU (DirectX) | LiteRT-LM |
| macOS | CPU (XNNPACK), GPU (Metal) | LiteRT-LM |
| Linux | CPU (XNNPACK), GPU (OpenCL) | LiteRT-LM |
| Android | CPU (XNNPACK), GPU (OpenCL), NPU (NNAPI) | LiteRT-LM |
| iOS | CPU (XNNPACK), GPU (Metal/Core ML) | LiteRT-LM |

One C++ library. All platforms. No per-platform backend switching needed.

## Build Wiring

```bash
NG_ENABLE_WEBNN=1 ./run-build.sh <platform> <build-id>
```

CMake requirements:
- `ENABLE_WEBNN:BOOL=ON`
- LiteRT-LM resolved via `ExternalProject_Add` (source) or `FindLiteRT.cmake`
  (pre-built).
- LiteRT-LM shared libraries present beside the browser binary.
- WebNN source files compiled when `ENABLE_WEBNN` is on.

Build dependencies:
- Bazel 7.6.1 (source builds) or pre-built libraries
- protobuf, flatbuffers (fetched by LiteRT-LM)
- Git LFS (for GPU prebuilt binaries)
- Windows: VS 2022 + DirectXShaderCompiler (for GPU)
- macOS: Xcode command line tools
- Android: NDK r28b+

## Integration With WebGPU

WebNN and WebGPU are complementary. The `MLTensor` API supports export to
`GPUBuffer` for zero-copy interop. This means an inference result from WebNN
(via LiteRT-LM) can be rendered directly by a WebGPU pipeline (via Dawn)
without CPU round-trip.

For this interop to work, both `ENABLE_WEBGPU` and `ENABLE_WEBNN` must be on.

## Acceptance

The build is not accepted from compile success alone. Milestone definitions
and exit criteria are in `docs/WEBNN_PROGRAM.md`.

Minimum lane harness checks:

- `ENABLE_WEBNN:BOOL=ON` in `CMakeCache.txt`.
- LiteRT-LM libraries present and loadable beside MiniBrowser.
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
