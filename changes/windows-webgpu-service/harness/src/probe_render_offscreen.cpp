// Offscreen render probe.
//
// Renders a single-colored triangle to a 4x4 color texture using the exact
// Dawn call shape the basic /webgpu-samples/ apps need (helloTriangle,
// rotatingCube, etc.), then copies to a readback buffer and verifies a
// specific pixel. No canvas, no HWND — isolates render-pipeline correctness
// from surface/present plumbing.
//
// Mapped WebCore files:
//   Implementation/WebGPUDeviceImpl.cpp         createRenderPipeline
//   Implementation/WebGPUCommandEncoderImpl.cpp beginRenderPass
//   Implementation/WebGPURenderPassEncoderImpl.cpp setPipeline, setVertexBuffer, draw
//   Implementation/WebGPUTextureImpl.cpp        createView
//
// If this probe passes but helloTriangle fails in the browser, the bug is in
// WebCore's translation (not Dawn). If this probe fails, the bug is below
// WebCore.

#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <thread>

namespace webgpu_host {

namespace {

const char* kShader = R"WGSL(
struct VSIn { @location(0) pos : vec2<f32>, @location(1) color : vec3<f32> };
struct VSOut { @builtin(position) pos : vec4<f32>, @location(0) color : vec3<f32> };
@vertex
fn vs(in : VSIn) -> VSOut {
  var out : VSOut;
  out.pos = vec4<f32>(in.pos, 0.0, 1.0);
  out.color = in.color;
  return out;
}
@fragment
fn fs(in : VSOut) -> @location(0) vec4<f32> {
  return vec4<f32>(in.color, 1.0);
}
)WGSL";

struct Vertex { float x, y, r, g, b; };

struct MapState { bool done = false; WGPUMapAsyncStatus status = WGPUMapAsyncStatus_Error; };
void onMapped(WGPUMapAsyncStatus s, WGPUStringView, void* ud1, void*) {
    auto* m = static_cast<MapState*>(ud1);
    if (!m) return;
    m->status = s; m->done = true;
}

} // namespace

ProbeOutcome probeRenderOffscreen(const GpuBootstrap& g) {
    ProbeOutcome o; o.name = "renderOffscreen";
    if (!g.device || !g.queue) { o.detail = "no device"; return o; }

    constexpr uint32_t kDim = 4;
    constexpr WGPUTextureFormat kFmt = WGPUTextureFormat_RGBA8Unorm;
    constexpr uint32_t kBytesPerPixel = 4;
    // D3D12/Dawn require 256-byte aligned bytesPerRow for copies.
    constexpr uint32_t kBytesPerRow = 256;
    constexpr uint32_t kReadbackSize = kBytesPerRow * kDim;

    // Full-green triangle covering the whole 4x4 color attachment.
    const std::array<Vertex, 3> verts{{
        {-3.0f, -1.0f, 0.0f, 1.0f, 0.0f},
        { 3.0f, -1.0f, 0.0f, 1.0f, 0.0f},
        { 0.0f,  3.0f, 0.0f, 1.0f, 0.0f},
    }};

    WGPUBufferDescriptor vDesc{};
    vDesc.label = {"probe verts", WGPU_STRLEN};
    vDesc.size  = sizeof(verts);
    vDesc.usage = WGPUBufferUsage_Vertex | WGPUBufferUsage_CopyDst;
    auto vbuf = wgpuDeviceCreateBuffer(g.device, &vDesc);
    if (!vbuf) { o.detail = "createBuffer(vertex) null"; return o; }
    wgpuQueueWriteBuffer(g.queue, vbuf, 0, verts.data(), sizeof(verts));

    WGPUShaderSourceWGSL src{};
    src.chain.next  = nullptr;
    src.chain.sType = WGPUSType_ShaderSourceWGSL;
    src.code        = {kShader, WGPU_STRLEN};
    WGPUShaderModuleDescriptor smDesc{};
    smDesc.nextInChain = &src.chain;
    auto shader = wgpuDeviceCreateShaderModule(g.device, &smDesc);
    if (!shader) { wgpuBufferRelease(vbuf); o.detail = "createShaderModule null"; return o; }

    WGPUVertexAttribute attrs[2]{};
    attrs[0].format         = WGPUVertexFormat_Float32x2;
    attrs[0].offset         = offsetof(Vertex, x);
    attrs[0].shaderLocation = 0;
    attrs[1].format         = WGPUVertexFormat_Float32x3;
    attrs[1].offset         = offsetof(Vertex, r);
    attrs[1].shaderLocation = 1;

    WGPUVertexBufferLayout vbl{};
    vbl.arrayStride    = sizeof(Vertex);
    vbl.stepMode       = WGPUVertexStepMode_Vertex;
    vbl.attributeCount = 2;
    vbl.attributes     = attrs;

    WGPUColorTargetState colorTarget{};
    colorTarget.format    = kFmt;
    colorTarget.writeMask = WGPUColorWriteMask_All;

    WGPUFragmentState frag{};
    frag.module      = shader;
    frag.entryPoint  = {"fs", WGPU_STRLEN};
    frag.targetCount = 1;
    frag.targets     = &colorTarget;

    WGPURenderPipelineDescriptor pipeDesc{};
    pipeDesc.layout             = nullptr;            // auto layout
    pipeDesc.vertex.module      = shader;
    pipeDesc.vertex.entryPoint  = {"vs", WGPU_STRLEN};
    pipeDesc.vertex.bufferCount = 1;
    pipeDesc.vertex.buffers     = &vbl;
    pipeDesc.primitive.topology = WGPUPrimitiveTopology_TriangleList;
    pipeDesc.primitive.cullMode = WGPUCullMode_None;
    pipeDesc.primitive.frontFace = WGPUFrontFace_CCW;
    pipeDesc.multisample.count  = 1;
    pipeDesc.multisample.mask   = 0xFFFFFFFF;
    pipeDesc.fragment           = &frag;

    auto pipeline = wgpuDeviceCreateRenderPipeline(g.device, &pipeDesc);
    if (!pipeline) {
        wgpuShaderModuleRelease(shader);
        wgpuBufferRelease(vbuf);
        o.detail = "createRenderPipeline null";
        return o;
    }

    WGPUTextureDescriptor tDesc{};
    tDesc.label         = {"probe color", WGPU_STRLEN};
    tDesc.dimension     = WGPUTextureDimension_2D;
    tDesc.size          = {kDim, kDim, 1};
    tDesc.format        = kFmt;
    tDesc.mipLevelCount = 1;
    tDesc.sampleCount   = 1;
    tDesc.usage         = WGPUTextureUsage_RenderAttachment | WGPUTextureUsage_CopySrc;
    auto color = wgpuDeviceCreateTexture(g.device, &tDesc);
    auto colorView = wgpuTextureCreateView(color, nullptr);

    WGPUBufferDescriptor rbDesc{};
    rbDesc.label = {"probe rb", WGPU_STRLEN};
    rbDesc.size  = kReadbackSize;
    rbDesc.usage = WGPUBufferUsage_MapRead | WGPUBufferUsage_CopyDst;
    auto rbBuf = wgpuDeviceCreateBuffer(g.device, &rbDesc);

    auto enc = wgpuDeviceCreateCommandEncoder(g.device, nullptr);

    WGPURenderPassColorAttachment att{};
    att.view       = colorView;
    att.loadOp     = WGPULoadOp_Clear;
    att.storeOp    = WGPUStoreOp_Store;
    att.clearValue = {1.0, 0.0, 0.0, 1.0};            // red, overwritten by green triangle
    att.depthSlice = WGPU_DEPTH_SLICE_UNDEFINED;

    WGPURenderPassDescriptor passDesc{};
    passDesc.colorAttachmentCount = 1;
    passDesc.colorAttachments     = &att;
    auto pass = wgpuCommandEncoderBeginRenderPass(enc, &passDesc);
    wgpuRenderPassEncoderSetPipeline(pass, pipeline);
    wgpuRenderPassEncoderSetVertexBuffer(pass, 0, vbuf, 0, sizeof(verts));
    wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
    wgpuRenderPassEncoderEnd(pass);
    wgpuRenderPassEncoderRelease(pass);

    WGPUImageCopyTexture texSrc{};
    texSrc.texture = color;
    texSrc.mipLevel = 0;
    texSrc.origin  = {0, 0, 0};
    texSrc.aspect  = WGPUTextureAspect_All;

    WGPUImageCopyBuffer bufDst{};
    bufDst.buffer = rbBuf;
    bufDst.layout.offset = 0;
    bufDst.layout.bytesPerRow = kBytesPerRow;
    bufDst.layout.rowsPerImage = kDim;

    WGPUExtent3D copySize{kDim, kDim, 1};
    wgpuCommandEncoderCopyTextureToBuffer(enc, &texSrc, &bufDst, &copySize);

    auto cb = wgpuCommandEncoderFinish(enc, nullptr);
    wgpuCommandEncoderRelease(enc);
    wgpuQueueSubmit(g.queue, 1, &cb);
    wgpuCommandBufferRelease(cb);

    MapState ms;
    WGPUBufferMapCallbackInfo cbi{};
    cbi.mode = WGPUCallbackMode_AllowProcessEvents;
    cbi.callback = onMapped;
    cbi.userdata1 = &ms;
    wgpuBufferMapAsync(rbBuf, WGPUMapMode_Read, 0, kReadbackSize, cbi);

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (!ms.done) {
        wgpuInstanceProcessEvents(g.instance);
        if (ms.done) break;
        if (std::chrono::steady_clock::now() > deadline) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    bool ok = false;
    uint8_t r = 0, g_ = 0, b = 0, a = 0;
    std::string detail;
    if (ms.done && ms.status == WGPUMapAsyncStatus_Success) {
        auto* px = static_cast<const uint8_t*>(
            wgpuBufferGetConstMappedRange(rbBuf, 0, kReadbackSize));
        if (!px) { detail = "getConstMappedRange null"; }
        else {
            // Center pixel at (kDim/2, kDim/2), row-major, bpp=4, pitch=kBytesPerRow.
            const uint8_t* p = px + (kDim / 2) * kBytesPerRow + (kDim / 2) * kBytesPerPixel;
            r  = p[0]; g_ = p[1]; b = p[2]; a = p[3];
            // Triangle fully covers texture → center pixel should be green (0,255,0,255).
            ok = (r < 20 && g_ > 230 && b < 20 && a > 230);
            detail = ok ? "ok (center pixel green)"
                        : "center pixel mismatch";
            wgpuBufferUnmap(rbBuf);
        }
    } else {
        detail = ms.done ? "mapAsync failed" : "mapAsync timed out";
    }

    char buf[256];
    std::snprintf(buf, sizeof(buf),
        "\"centerPixel\": [%u, %u, %u, %u], "
        "\"textureSize\": [%u, %u], "
        "\"textureFormat\": \"RGBA8Unorm\"",
        r, g_, b, a, kDim, kDim);
    o.jsonBody = buf;

    wgpuBufferRelease(rbBuf);
    wgpuTextureViewRelease(colorView);
    wgpuTextureRelease(color);
    wgpuRenderPipelineRelease(pipeline);
    wgpuShaderModuleRelease(shader);
    wgpuBufferRelease(vbuf);

    o.ok = ok;
    o.detail = detail;
    return o;
}

} // namespace webgpu_host
