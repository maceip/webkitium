#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace ng {

// ----- Backend and device -----

enum class WebNnBackend : uint8_t {
    CPU,
    GPU,
    NPU,
};

enum class WebNnBackendStatus : uint8_t {
    Available,
    Unavailable,
    NeedsDriverUpdate,
};

struct WebNnDeviceCapabilities {
    bool hasCpu { true };
    bool hasGpu { false };
    bool hasNpu { false };
    uint64_t gpuVramBytes { 0 };
    uint64_t systemRamBytes { 0 };
    unsigned cpuCoreCount { 0 };
    std::string gpuDescription;
};

// ----- Model identity and metadata -----

using ModelId = std::string;

struct ModelDescriptor {
    ModelId id;
    std::string name;
    std::string version;
    std::string format;             // "litertlm", "tflite", etc.
    std::string url;                // download URL
    std::string sha256;             // hex-encoded integrity hash
    uint64_t sizeBytes { 0 };       // expected file size
    uint64_t maxContextTokens { 0 };
    std::vector<std::string> supportedBackends; // "cpu", "gpu", "npu"
    bool supportsVision { false };
    bool supportsAudio { false };
    bool supportsToolUse { false };
};

enum class ModelAvailability : uint8_t {
    Unavailable,
    Downloadable,
    Downloading,
    Available,
};

// ----- Download progress -----

struct DownloadProgress {
    uint64_t bytesReceived { 0 };
    uint64_t totalBytes { 0 };
    double fractionComplete { 0.0 };
};

using DownloadProgressCallback = std::function<void(const DownloadProgress&)>;

// ----- Inference session config -----

struct SessionConfig {
    WebNnBackend backend { WebNnBackend::CPU };
    unsigned maxTokens { 4096 };
    float temperature { 1.0f };
    float topP { 1.0f };
    unsigned topK { 0 };
    unsigned maxOutputTokens { 2048 };
};

// ----- Inference I/O -----

struct InferenceInput {
    std::string role;               // "user", "system"
    std::string contentText;
    std::string imagePath;          // optional, for multimodal
    std::string audioPath;          // optional, for multimodal
};

struct InferenceOutput {
    std::string text;
    bool isPartial { false };       // true for streaming chunks
    bool isDone { false };          // true for final token
};

using StreamCallback = std::function<void(const InferenceOutput&)>;

// ----- Storage -----

struct CachedModel {
    ModelId id;
    std::string localPath;
    uint64_t sizeBytes { 0 };
    std::string sha256;
    int64_t lastAccessTimestamp { 0 };  // seconds since epoch
};

struct StorageQuota {
    uint64_t usedBytes { 0 };
    uint64_t availableBytes { 0 };
    uint64_t maxBytes { 0 };
};

} // namespace ng
