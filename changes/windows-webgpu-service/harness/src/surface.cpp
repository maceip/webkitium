// HWND -> WGPUSurface plumbing.
//
// The in-tree code this replaces is WebCore::WebGPU::GPUImpl::createPresentationContext
// (see changes/windows-webgpu-service/README.md § HWND surface). When we wire
// GPUCanvasContext::create for Windows, it should:
//   1. populate GPUPresentationContextDescriptor::{hwnd, hinstance}
//   2. pass them through to WebGPU::GPUImpl
//   3. call wgpuInstanceCreateSurface() with the same struct shape used below.

#include "webgpu_host/Host.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <webgpu/webgpu.h>

#include <algorithm>
#include <cstdio>

namespace webgpu_host {

namespace {

const char* formatName(WGPUTextureFormat f) {
    switch (f) {
    case WGPUTextureFormat_BGRA8Unorm:      return "BGRA8Unorm";
    case WGPUTextureFormat_RGBA8Unorm:      return "RGBA8Unorm";
    case WGPUTextureFormat_RGBA16Float:     return "RGBA16Float";
    case WGPUTextureFormat_BGRA8UnormSrgb:  return "BGRA8UnormSrgb";
    default:                                return "Other";
    }
}

WGPUTextureFormat pickFormat(const WGPUSurfaceCapabilities& caps) {
    // Prefer BGRA8Unorm so we match the format WebCore's Windows path will
    // configure once GPUCanvasContext::create is implemented. Fallback to
    // the first reported format.
    for (size_t i = 0; i < caps.formatCount; ++i) {
        if (caps.formats[i] == WGPUTextureFormat_BGRA8Unorm)
            return WGPUTextureFormat_BGRA8Unorm;
    }
    return caps.formatCount ? caps.formats[0] : WGPUTextureFormat_BGRA8Unorm;
}

} // namespace

bool attachSurface(const GpuBootstrap& g,
                   HWND hwnd,
                   HINSTANCE hinst,
                   uint32_t w,
                   uint32_t h,
                   SurfaceBinding& out) {
    // Dawn v20260410.140140 (our pin): the type is WGPUSurfaceSourceWindowsHWND.
    // The older name WGPUSurfaceDescriptorFromWindowsHWND was removed before this
    // release. If you get a compile error here, check config/vcpkg-configuration.json.
    WGPUSurfaceSourceWindowsHWND fromHwnd{};
    fromHwnd.chain.next  = nullptr;
    fromHwnd.chain.sType = WGPUSType_SurfaceSourceWindowsHWND;
    fromHwnd.hinstance   = reinterpret_cast<void*>(hinst);
    fromHwnd.hwnd        = reinterpret_cast<void*>(hwnd);

    WGPUSurfaceDescriptor desc{};
    desc.nextInChain = &fromHwnd.chain;
    desc.label       = {"webgpu_host HWND surface", WGPU_STRLEN};

    out.surface = wgpuInstanceCreateSurface(g.instance, &desc);
    if (!out.surface) return false;
    out.width  = w;
    out.height = h;

    WGPUSurfaceCapabilities caps{};
    if (wgpuSurfaceGetCapabilities(out.surface, g.adapter, &caps) != WGPUStatus_Success) {
        wgpuSurfaceRelease(out.surface);
        out.surface = nullptr;
        return false;
    }
    out.format = pickFormat(caps);
    wgpuSurfaceCapabilitiesFreeMembers(caps);
    return true;
}

bool configureSurface(const GpuBootstrap& g, SurfaceBinding& b) {
    if (!b.surface || !g.device) return false;

    WGPUSurfaceConfiguration cfg{};
    cfg.nextInChain = nullptr;
    cfg.device      = g.device;
    cfg.format      = b.format;
    cfg.usage       = b.usage;
    cfg.viewFormatCount = 0;
    cfg.viewFormats     = nullptr;
    cfg.alphaMode       = WGPUCompositeAlphaMode_Auto;
    cfg.width           = std::max<uint32_t>(1, b.width);
    cfg.height          = std::max<uint32_t>(1, b.height);
    cfg.presentMode     = WGPUPresentMode_Fifo;

    wgpuSurfaceConfigure(b.surface, &cfg);
    b.configured = true;
    std::fprintf(stderr,
                 "[webgpu_host] surface configured: %ux%u format=%s\n",
                 b.width, b.height, formatName(b.format));
    return true;
}

void destroySurface(SurfaceBinding& b) {
    if (b.surface) {
        wgpuSurfaceUnconfigure(b.surface);
        wgpuSurfaceRelease(b.surface);
        b.surface = nullptr;
    }
    b.configured = false;
}

WGPUTextureView acquireColorView(SurfaceBinding& b, WGPUTexture& outTexture) {
    outTexture = nullptr;
    if (!b.surface) return nullptr;

    WGPUSurfaceTexture st{};
    wgpuSurfaceGetCurrentTexture(b.surface, &st);
    switch (st.status) {
    case WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal:
    case WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal:
        break;
    case WGPUSurfaceGetCurrentTextureStatus_Timeout:
    case WGPUSurfaceGetCurrentTextureStatus_Outdated:
    case WGPUSurfaceGetCurrentTextureStatus_Lost:
        // Caller should reconfigure on the next resize event.
        return nullptr;
    default:
        return nullptr;
    }
    if (!st.texture) return nullptr;
    outTexture = st.texture;

    WGPUTextureViewDescriptor viewDesc{};
    viewDesc.label           = {"webgpu_host surface view", WGPU_STRLEN};
    viewDesc.format          = wgpuTextureGetFormat(st.texture);
    viewDesc.dimension       = WGPUTextureViewDimension_2D;
    viewDesc.baseMipLevel    = 0;
    viewDesc.mipLevelCount   = 1;
    viewDesc.baseArrayLayer  = 0;
    viewDesc.arrayLayerCount = 1;
    viewDesc.aspect          = WGPUTextureAspect_All;
    return wgpuTextureCreateView(st.texture, &viewDesc);
}

} // namespace webgpu_host
