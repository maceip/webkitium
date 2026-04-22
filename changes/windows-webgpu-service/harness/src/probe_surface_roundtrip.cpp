// Surface roundtrip probe.
//
// Assumes the caller has already attached a surface to an HWND and the host
// is about to render. The probe asks Dawn's current surface state: can we
// acquire a texture, does the reported format match what we configured, do
// the reported capabilities look sane?
//
// Mapped WebCore files:
//   Implementation/WebGPUImpl.cpp (GPUImpl::createPresentationContext)
//   Implementation/WebGPU/WebGPUExt.h (wgpuDeviceCreateSwapChain stubs that
//   should be replaced with the wgpuSurface* entry points this probe uses)
//   Modules/WebGPU/GPUCanvasContext.cpp (returns nullptr on non-Cocoa today)

#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <cstdio>
#include <string>

namespace webgpu_host {

namespace {
const char* formatName(WGPUTextureFormat f) {
    switch (f) {
    case WGPUTextureFormat_BGRA8Unorm:     return "BGRA8Unorm";
    case WGPUTextureFormat_RGBA8Unorm:     return "RGBA8Unorm";
    case WGPUTextureFormat_BGRA8UnormSrgb: return "BGRA8UnormSrgb";
    case WGPUTextureFormat_RGBA16Float:    return "RGBA16Float";
    default:                               return "Other";
    }
}
} // namespace

ProbeOutcome probeSurfaceRoundtrip(const GpuBootstrap& g, const SurfaceBinding& b) {
    ProbeOutcome o; o.name = "surfaceRoundtrip";
    if (!g.device || !b.surface || !b.configured) {
        o.detail = "surface not configured";
        return o;
    }

    WGPUSurfaceCapabilities caps{};
    auto capsOk = wgpuSurfaceGetCapabilities(b.surface, g.adapter, &caps) == WGPUStatus_Success;

    WGPUSurfaceTexture st{};
    wgpuSurfaceGetCurrentTexture(b.surface, &st);
    const bool acquired = st.texture != nullptr &&
        (st.status == WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal ||
         st.status == WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal);

    WGPUTextureFormat actualFormat = acquired
        ? wgpuTextureGetFormat(st.texture)
        : WGPUTextureFormat_Undefined;
    uint32_t acquiredW = acquired ? wgpuTextureGetWidth(st.texture) : 0;
    uint32_t acquiredH = acquired ? wgpuTextureGetHeight(st.texture) : 0;
    if (acquired) wgpuTextureRelease(st.texture);

    char buf[512];
    std::snprintf(buf, sizeof(buf),
        "\"configuredFormat\": \"%s\", "
        "\"acquiredTexture\": %s, "
        "\"acquiredFormat\": \"%s\", "
        "\"acquiredWidth\": %u, "
        "\"acquiredHeight\": %u, "
        "\"capabilityFormatCount\": %u, "
        "\"currentTextureStatus\": %u",
        formatName(b.format),
        acquired ? "true" : "false",
        formatName(actualFormat),
        acquiredW, acquiredH,
        static_cast<unsigned>(capsOk ? caps.formatCount : 0),
        static_cast<unsigned>(st.status));
    o.jsonBody = buf;

    if (capsOk) wgpuSurfaceCapabilitiesFreeMembers(caps);

    o.ok = acquired && actualFormat == b.format;
    o.detail = o.ok ? "ok" :
        (!acquired ? "surfaceGetCurrentTexture failed" : "format mismatch");
    return o;
}

} // namespace webgpu_host
