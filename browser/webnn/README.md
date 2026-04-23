# WebNN

Portable model management and inference orchestration for on-device ML.
This module owns the cross-platform logic for model lifecycle, backend
selection, and inference session management. It does not include WebKit,
platform GPU APIs, or OS-specific storage.

## Scope

Portable code in this directory:

- `ModelRegistry`: tracks available, downloading, and cached models.
- `ModelDownloader`: fetches `.litertlm` models from URLs with progress,
  resume, and integrity verification (SHA-256).
- `ModelStorage`: abstract interface for persistent model cache (OPFS,
  filesystem, etc.) with eviction policy.
- `InferenceSession`: manages a stateful inference session including
  KV cache lifetime, context window, and session cloning.
- `BackendSelector`: chooses CPU, GPU, or NPU backend based on device
  capabilities and caller preference.
- `WebNnController`: validates requests, enforces permissions policy,
  and dispatches to the platform inference provider.

Platform bindings (not in this directory):

- Windows: DirectX GPU delegate, filesystem model cache.
- macOS/iOS: Metal accelerator, Core ML delegate, filesystem cache.
- Android: OpenCL / NNAPI delegate, app-private storage.
- Linux: XNNPACK CPU, XDG cache directory.

Platform adapters are declared in `platform/PlatformAdapters.h` via
`PlatformWebNnProvider` and `PlatformModelStorage`.

---
