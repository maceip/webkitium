// Compute smoke probe.
//
// Runs a tiny compute pipeline that writes a predictable pattern into a
// storage buffer; copies it to a CPU-visible buffer; maps and verifies.
// This is the exact end-to-end path patches 0015–0019 enable in WebCore:
//   - createShaderModule (WGSL)
//   - createComputePipeline (auto layout, patch 0016)
//   - beginComputePass (patch 0015) + setPipeline + setBindGroup + dispatch
//   - submit + map-async readback (patches 0017, 0018)
//
// If this probe fails while the page-side WebGPU path is "fine," the bug is
// almost always in WebCore's translation layer, not Dawn.
//
// Mapped WebCore files:
//   Implementation/WebGPUDeviceImpl.cpp         createShaderModule, createComputePipeline
//   Implementation/WebGPUCommandEncoderImpl.cpp beginComputePass
//   Implementation/WebGPUComputePassEncoderImpl.cpp dispatch / setBindGroup
//   Implementation/WebGPUQueueImpl.cpp           writeBuffer, submit

#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <string>
#include <thread>

namespace webgpu_host {

namespace {

const char* kCompute = R"WGSL(
@group(0) @binding(0) var<storage, read_write> data : array<u32>;

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
  let i = gid.x;
  if (i >= arrayLength(&data)) { return; }
  data[i] = 0xC0DE0000u | i;
}
)WGSL";

struct MapState { bool done = false; WGPUMapAsyncStatus status = WGPUMapAsyncStatus_Error; };
std::string toStr(WGPUStringView v) {
    if (!v.data) return {};
    if (v.length == WGPU_STRLEN) return std::string{v.data};
    return std::string{v.data, v.length};
}
void onMapped(WGPUMapAsyncStatus s, WGPUStringView, void* ud1, void*) {
    auto* m = static_cast<MapState*>(ud1);
    if (!m) return;
    m->status = s; m->done = true;
}

} // namespace

ProbeOutcome probeComputeSmoke(const GpuBootstrap& g) {
    ProbeOutcome o; o.name = "computeSmoke";
    if (!g.device || !g.queue) { o.detail = "no device"; return o; }

    constexpr uint32_t kCount = 1024;
    constexpr uint64_t kBytes = kCount * sizeof(uint32_t);

    WGPUShaderSourceWGSL src{};
    src.chain.next  = nullptr;
    src.chain.sType = WGPUSType_ShaderSourceWGSL;
    src.code        = {kCompute, WGPU_STRLEN};
    WGPUShaderModuleDescriptor smDesc{};
    smDesc.nextInChain = &src.chain;
    auto shader = wgpuDeviceCreateShaderModule(g.device, &smDesc);
    if (!shader) { o.detail = "createShaderModule null"; return o; }

    WGPUComputePipelineDescriptor pipeDesc{};
    pipeDesc.layout = nullptr;                          // auto layout
    pipeDesc.compute.module = shader;
    pipeDesc.compute.entryPoint = {"main", WGPU_STRLEN};
    auto pipeline = wgpuDeviceCreateComputePipeline(g.device, &pipeDesc);
    if (!pipeline) {
        wgpuShaderModuleRelease(shader);
        o.detail = "createComputePipeline null";
        return o;
    }

    WGPUBufferDescriptor gpuDesc{};
    gpuDesc.size  = kBytes;
    gpuDesc.usage = WGPUBufferUsage_Storage | WGPUBufferUsage_CopySrc;
    auto gpuBuf = wgpuDeviceCreateBuffer(g.device, &gpuDesc);

    WGPUBufferDescriptor rbDesc{};
    rbDesc.size  = kBytes;
    rbDesc.usage = WGPUBufferUsage_MapRead | WGPUBufferUsage_CopyDst;
    auto rbBuf  = wgpuDeviceCreateBuffer(g.device, &rbDesc);

    auto bgl = wgpuComputePipelineGetBindGroupLayout(pipeline, 0);

    WGPUBindGroupEntry entry{};
    entry.binding = 0;
    entry.buffer  = gpuBuf;
    entry.size    = kBytes;

    WGPUBindGroupDescriptor bgDesc{};
    bgDesc.layout = bgl;
    bgDesc.entryCount = 1;
    bgDesc.entries = &entry;
    auto bg = wgpuDeviceCreateBindGroup(g.device, &bgDesc);

    auto enc = wgpuDeviceCreateCommandEncoder(g.device, nullptr);
    auto pass = wgpuCommandEncoderBeginComputePass(enc, nullptr);
    wgpuComputePassEncoderSetPipeline(pass, pipeline);
    wgpuComputePassEncoderSetBindGroup(pass, 0, bg, 0, nullptr);
    wgpuComputePassEncoderDispatchWorkgroups(pass, (kCount + 63) / 64, 1, 1);
    wgpuComputePassEncoderEnd(pass);
    wgpuComputePassEncoderRelease(pass);
    wgpuCommandEncoderCopyBufferToBuffer(enc, gpuBuf, 0, rbBuf, 0, kBytes);
    auto cb = wgpuCommandEncoderFinish(enc, nullptr);
    wgpuCommandEncoderRelease(enc);
    wgpuQueueSubmit(g.queue, 1, &cb);
    wgpuCommandBufferRelease(cb);

    MapState ms;
    WGPUBufferMapCallbackInfo cbi{};
    cbi.mode = WGPUCallbackMode_AllowProcessEvents;
    cbi.callback = onMapped;
    cbi.userdata1 = &ms;
    wgpuBufferMapAsync(rbBuf, WGPUMapMode_Read, 0, kBytes, cbi);

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(5);
    while (!ms.done) {
        wgpuInstanceProcessEvents(g.instance);
        if (ms.done) break;
        if (std::chrono::steady_clock::now() > deadline) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    bool ok = false;
    uint32_t mismatch = static_cast<uint32_t>(-1);
    std::string detail;
    if (ms.done && ms.status == WGPUMapAsyncStatus_Success) {
        auto* data = static_cast<const uint32_t*>(
            wgpuBufferGetConstMappedRange(rbBuf, 0, kBytes));
        if (!data) {
            detail = "getConstMappedRange null";
        } else {
            ok = true;
            for (uint32_t i = 0; i < kCount; ++i) {
                if (data[i] != (0xC0DE0000u | i)) { ok = false; mismatch = i; break; }
            }
            detail = ok ? "ok (" + std::to_string(kCount) + " elements)"
                        : "mismatch at index " + std::to_string(mismatch);
            wgpuBufferUnmap(rbBuf);
        }
    } else {
        detail = ms.done ? "mapAsync failed" : "mapAsync timed out";
    }

    char buf[256];
    std::snprintf(buf, sizeof(buf),
        "\"elements\": %u, "
        "\"workgroups\": %u, "
        "\"mismatchIndex\": %lld, "
        "\"mapAsyncStatus\": %u",
        kCount, (kCount + 63) / 64,
        static_cast<long long>(ok ? -1 : mismatch),
        static_cast<unsigned>(ms.status));
    o.jsonBody = buf;

    wgpuBindGroupRelease(bg);
    wgpuBindGroupLayoutRelease(bgl);
    wgpuBufferRelease(rbBuf);
    wgpuBufferRelease(gpuBuf);
    wgpuComputePipelineRelease(pipeline);
    wgpuShaderModuleRelease(shader);

    o.ok = ok;
    o.detail = detail;
    return o;
}

} // namespace webgpu_host
