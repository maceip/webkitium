// Public types for the Windows WebGPU harness.
//
// Names and shapes mirror WebCore/Modules/WebGPU/Implementation so that when
// WebKit builds resume, the in-tree code for canvas/present can be pasted
// almost verbatim. See docs/INTEGRATION.md for the 1:1 mapping.

#pragma once

#include <webgpu/webgpu.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <optional>
#include <span>
#include <string>
#include <string_view>

struct HWND__;
struct HINSTANCE__;
using HWND = HWND__*;
using HINSTANCE = HINSTANCE__*;

namespace webgpu_host {

// Knobs from the CLI.
struct Config {
    enum class Scene { Ball, Triangle, None };
    enum class Mode  { Demo, Probe };

    Mode mode           = Mode::Demo;
    Scene scene         = Scene::Ball;
    uint32_t width      = 960;
    uint32_t height     = 640;
    uint32_t frameLimit = 0;                 // 0 = infinite (demo)
    WGPUBackendType backendType = WGPUBackendType_D3D12;
    std::chrono::milliseconds pumpTimeout{3000};
    std::string probeJsonPath;               // optional
    std::string suiteSpec;                   // e.g. "all" or "adapter,device,compute"
    bool visible        = true;
    bool headless       = false;             // skip window if no scene probe requested
};

// Everything built by `dawn_bootstrap.cpp`.
//
// Maps to WebCore::WebGPU::GPUImpl (instance) and its requestAdapter/
// adapter.requestDevice async paths (which pump with wgpuInstanceProcessEvents
// per changes/windows-webgpu-service/README.md § Dawn event pumping).
struct GpuBootstrap {
    WGPUInstance instance = nullptr;
    WGPUAdapter  adapter  = nullptr;
    WGPUDevice   device   = nullptr;
    WGPUQueue    queue    = nullptr;

    std::string adapterVendor;
    std::string adapterDevice;
    std::string adapterDescription;
    WGPUBackendType adapterBackend = WGPUBackendType_Undefined;
    WGPULimits limits{};

    std::string lastError;
};

// Maps to WebCore::WebGPU::PresentationContextImpl on Cocoa. Windows has no
// equivalent in-tree yet (GPUCanvasContext::create returns nullptr on
// non-Cocoa). This struct is the template for that implementation.
struct SurfaceBinding {
    WGPUSurface surface   = nullptr;
    WGPUTextureFormat format = WGPUTextureFormat_BGRA8Unorm;
    WGPUTextureUsage  usage  = WGPUTextureUsage_RenderAttachment;
    uint32_t width        = 0;
    uint32_t height       = 0;
    bool configured       = false;
};

// Scene interface. `update` is the rAF tick; `render` encodes and submits one
// render pass against the given swapchain texture view.
struct SceneContext {
    WGPUDevice      device;
    WGPUQueue       queue;
    WGPUTextureFormat colorFormat;
    uint32_t        width;
    uint32_t        height;
    double          dtSeconds;
    double          tSeconds;
};

class Scene {
public:
    virtual ~Scene() = default;
    virtual bool init(WGPUDevice, WGPUTextureFormat) = 0;
    virtual void resize(uint32_t width, uint32_t height) = 0;
    virtual void tick(const SceneContext&, WGPUTextureView colorView) = 0;
    virtual const char* name() const = 0;
};

// Result of a single frame attempt.
struct FrameResult {
    bool submitted = false;
    bool presented = false;
    std::string error;
};

// Probe output (see docs/INTEGRATION.md for runner-report mapping).
struct ProbeReport {
    bool gpuAvailable      = false;
    bool queueAvailable    = false;
    bool surfaceConfigured = false;
    uint32_t framesSubmitted = 0;
    uint32_t framesPresented = 0;
    std::string adapterBackend;
    std::string adapterVendor;
    std::string adapterDevice;
    std::string surfaceFormat;
    std::string lastError;
    // Pre-formatted JSON for the "probes" object. Empty if no suite ran.
    std::string suitesJson;
    bool suitesAllOk = true;
};

// dawn_bootstrap.cpp
bool createGpuBootstrap(const Config&, GpuBootstrap&);
void destroyGpuBootstrap(GpuBootstrap&);
void pumpDawnEvents(WGPUInstance, std::chrono::milliseconds timeout, bool& done);

// surface.cpp
bool attachSurface(const GpuBootstrap&, HWND, HINSTANCE, uint32_t w, uint32_t h, SurfaceBinding&);
bool configureSurface(const GpuBootstrap&, SurfaceBinding&);
void destroySurface(SurfaceBinding&);
// Acquire current texture; returns nullptr on transient failure (resize).
WGPUTextureView acquireColorView(SurfaceBinding&, WGPUTexture& outTexture);

// scene_*.cpp
std::unique_ptr<Scene> createBouncingBallScene();
std::unique_ptr<Scene> createTriangleScene();

// probe.cpp
bool writeProbeReport(const std::string& path, const ProbeReport&, std::string& err);

// main.cpp uses this to centralize error formatting for failures during
// bootstrap/render.
std::string formatDawnError(const char* stage, const char* detail);

} // namespace webgpu_host
