// Dawn instance / adapter / device bring-up.
//
// This is the Windows equivalent of what WebCore::WebGPU::GPUImpl does when
// navigator.gpu.requestAdapter / adapter.requestDevice run. We intentionally
// mirror the call shape and pumping loop from
// Source/WebCore/Modules/WebGPU/Implementation/WebGPUImpl.cpp and
// WebGPUAdapterImpl.cpp (see webgpu-service/README.md § Dawn event pumping),
// so translating this file back into the in-tree patch is mechanical.

#include "webgpu_host/Host.h"

#include <webgpu/webgpu.h>

#include <chrono>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>

namespace webgpu_host {

namespace {

const char* backendName(WGPUBackendType b) {
    switch (b) {
    case WGPUBackendType_D3D11:    return "D3D11";
    case WGPUBackendType_D3D12:    return "D3D12";
    case WGPUBackendType_Metal:    return "Metal";
    case WGPUBackendType_Vulkan:   return "Vulkan";
    case WGPUBackendType_OpenGL:   return "OpenGL";
    case WGPUBackendType_OpenGLES: return "OpenGLES";
    case WGPUBackendType_Null:     return "Null";
    default:                       return "Undefined";
    }
}

// WGPUStringView -> std::string. Dawn accepts both null-terminated and
// explicit-length string views.
std::string toString(WGPUStringView v) {
    if (!v.data) return {};
    if (v.length == WGPU_STRLEN) return std::string{v.data};
    return std::string{v.data, v.length};
}

struct AdapterState {
    WGPUAdapter adapter = nullptr;
    std::string message;
    bool done = false;
};

struct DeviceState {
    WGPUDevice device = nullptr;
    std::string message;
    bool done = false;
};

void onAdapterRequestEnded(WGPURequestAdapterStatus status,
                           WGPUAdapter adapter,
                           WGPUStringView message,
                           void* userdata1,
                           void* /*userdata2*/) {
    auto* s = static_cast<AdapterState*>(userdata1);
    if (!s) return;
    s->message = toString(message);
    if (status == WGPURequestAdapterStatus_Success && adapter) {
        s->adapter = adapter;
    }
    s->done = true;
}

void onDeviceRequestEnded(WGPURequestDeviceStatus status,
                          WGPUDevice device,
                          WGPUStringView message,
                          void* userdata1,
                          void* /*userdata2*/) {
    auto* s = static_cast<DeviceState*>(userdata1);
    if (!s) return;
    s->message = toString(message);
    if (status == WGPURequestDeviceStatus_Success && device) {
        s->device = device;
    }
    s->done = true;
}

void onUncapturedError(const WGPUDevice*,
                       WGPUErrorType type,
                       WGPUStringView message,
                       void* userdata1,
                       void* /*userdata2*/) {
    (void)type;
    auto* err = static_cast<std::string*>(userdata1);
    auto msg = toString(message);
    if (err) *err = msg;
    std::fprintf(stderr, "[webgpu_host] uncaptured error: %s\n", msg.c_str());
}

bool pumpUntil(WGPUInstance instance, bool& done, std::chrono::milliseconds timeout) {
    const auto deadline = std::chrono::steady_clock::now() + timeout;
    while (!done) {
        wgpuInstanceProcessEvents(instance);
        if (done) break;
        if (std::chrono::steady_clock::now() > deadline) return false;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    return true;
}

} // namespace

void pumpDawnEvents(WGPUInstance instance,
                    std::chrono::milliseconds timeout,
                    bool& done) {
    pumpUntil(instance, done, timeout);
}

bool createGpuBootstrap(const Config& cfg, GpuBootstrap& out) {
    // Instance. Cocoa uses WGPUInstanceCocoaDescriptor; Windows has no equivalent
    // in-chain struct, so pass a bare descriptor. This matches the #if PLATFORM
    // split from patches/windows/0001-windows-dawn-request-adapter-runtime.
    WGPUInstanceDescriptor instanceDesc{};
    out.instance = wgpuCreateInstance(&instanceDesc);
    if (!out.instance) {
        out.lastError = "wgpuCreateInstance returned null (is webgpu_dawn.dll loaded?)";
        return false;
    }

    // Adapter. Match patches/windows/0001 (D3D12) with 0021's relaxation
    // option: callers can force `Undefined` so Dawn picks the best adapter.
    WGPURequestAdapterOptions opts{};
    opts.nextInChain = nullptr;
    opts.featureLevel = WGPUFeatureLevel_Undefined;
    opts.powerPreference = WGPUPowerPreference_HighPerformance;
    opts.forceFallbackAdapter = 0;
    opts.backendType = cfg.backendType;
    opts.compatibleSurface = nullptr;

    AdapterState adapterState;
    WGPURequestAdapterCallbackInfo adapterCb{};
    adapterCb.nextInChain = nullptr;
    adapterCb.mode = WGPUCallbackMode_AllowProcessEvents;
    adapterCb.callback = onAdapterRequestEnded;
    adapterCb.userdata1 = &adapterState;
    adapterCb.userdata2 = nullptr;
    wgpuInstanceRequestAdapter(out.instance, &opts, adapterCb);

    if (!pumpUntil(out.instance, adapterState.done, cfg.pumpTimeout) || !adapterState.adapter) {
        out.lastError = adapterState.message.empty()
            ? std::string{"requestAdapter timed out"}
            : "requestAdapter failed: " + adapterState.message;
        return false;
    }
    out.adapter = adapterState.adapter;

    WGPUAdapterInfo info{};
    if (wgpuAdapterGetInfo(out.adapter, &info) == WGPUStatus_Success) {
        out.adapterVendor      = toString(info.vendor);
        out.adapterDevice      = toString(info.device);
        out.adapterDescription = toString(info.description);
        out.adapterBackend     = info.backendType;
        wgpuAdapterInfoFreeMembers(info);
    } else {
        out.adapterBackend = cfg.backendType;
    }

    WGPULimits adapterLimits{};
    if (wgpuAdapterGetLimits(out.adapter, &adapterLimits) == WGPUStatus_Success) {
        out.limits = adapterLimits;
    }

    // Device. patches/windows/0014 makes requestDevice tolerate a null
    // descriptor; pass an explicit one for clarity.
    WGPUDeviceDescriptor devDesc{};
    devDesc.label = {"webgpu_host device", WGPU_STRLEN};
    devDesc.requiredFeatureCount = 0;
    devDesc.requiredFeatures = nullptr;
    devDesc.requiredLimits = nullptr;
    devDesc.defaultQueue.label = {"default", WGPU_STRLEN};

    // Uncaptured-error callback, device lost callback both use the same
    // "callback info" pattern as request adapter. Store errors in out.lastError
    // so the render loop can surface them in the probe report.
    devDesc.uncapturedErrorCallbackInfo.callback = onUncapturedError;
    devDesc.uncapturedErrorCallbackInfo.userdata1 = &out.lastError;
    devDesc.uncapturedErrorCallbackInfo.userdata2 = nullptr;

    DeviceState deviceState;
    WGPURequestDeviceCallbackInfo deviceCb{};
    deviceCb.nextInChain = nullptr;
    deviceCb.mode = WGPUCallbackMode_AllowProcessEvents;
    deviceCb.callback = onDeviceRequestEnded;
    deviceCb.userdata1 = &deviceState;
    deviceCb.userdata2 = nullptr;
    wgpuAdapterRequestDevice(out.adapter, &devDesc, deviceCb);

    if (!pumpUntil(out.instance, deviceState.done, cfg.pumpTimeout) || !deviceState.device) {
        out.lastError = deviceState.message.empty()
            ? std::string{"requestDevice timed out"}
            : "requestDevice failed: " + deviceState.message;
        return false;
    }
    out.device = deviceState.device;
    out.queue  = wgpuDeviceGetQueue(out.device);
    if (!out.queue) {
        out.lastError = "wgpuDeviceGetQueue returned null";
        return false;
    }

    std::fprintf(stderr,
                 "[webgpu_host] adapter: backend=%s vendor=\"%s\" device=\"%s\"\n",
                 backendName(out.adapterBackend),
                 out.adapterVendor.c_str(),
                 out.adapterDevice.c_str());
    return true;
}

void destroyGpuBootstrap(GpuBootstrap& g) {
    if (g.queue)    { wgpuQueueRelease(g.queue);       g.queue = nullptr; }
    if (g.device)   { wgpuDeviceRelease(g.device);     g.device = nullptr; }
    if (g.adapter)  { wgpuAdapterRelease(g.adapter);   g.adapter = nullptr; }
    if (g.instance) { wgpuInstanceRelease(g.instance); g.instance = nullptr; }
}

std::string formatDawnError(const char* stage, const char* detail) {
    std::string s = stage ? stage : "";
    if (detail && *detail) { s += ": "; s += detail; }
    return s;
}

} // namespace webgpu_host
