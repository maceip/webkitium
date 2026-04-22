// Buffer readback probe.
//
// Verifies that Dawn's writeBuffer + mapAsync path works end-to-end on
// Windows with the same call shape WebCore uses after
// changes/windows-webgpu-service/patches/windows/0017-windows-dawn-buffer-size-readback
// (wgpuBufferGetInitialSize returning the real size on Windows).
//
// Mapped WebCore files:
//   Implementation/WebGPUQueueImpl.cpp         writeBuffer
//   Implementation/WebGPUBufferImpl.cpp        mapAsync / getMappedRange / unmap
//   Implementation/WebGPU/WebGPUExt.h          wgpuBufferGetInitialSize
//
// Sequence (all through Dawn's native C API):
//   1. Create UPLOAD buffer (CopySrc | MapWrite) OR use queue.writeBuffer
//   2. Create READBACK buffer (CopyDst | MapRead)
//   3. Copy upload -> readback via a command encoder
//   4. mapAsync(MapRead) on the readback buffer, pump events until ready
//   5. Compare the mapped bytes against what we wrote

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

struct MapState { bool done = false; WGPUMapAsyncStatus status = WGPUMapAsyncStatus_Error; std::string message; };

std::string toStr(WGPUStringView v) {
    if (!v.data) return {};
    if (v.length == WGPU_STRLEN) return std::string{v.data};
    return std::string{v.data, v.length};
}

void onMapped(WGPUMapAsyncStatus status, WGPUStringView message, void* ud1, void*) {
    auto* s = static_cast<MapState*>(ud1);
    if (!s) return;
    s->status = status;
    s->message = toStr(message);
    s->done = true;
}

} // namespace

ProbeOutcome probeBufferReadback(const GpuBootstrap& g) {
    ProbeOutcome o; o.name = "bufferReadback";
    if (!g.device || !g.queue) { o.detail = "no device"; return o; }

    constexpr uint32_t kCount = 256;
    constexpr uint64_t kBytes = kCount * sizeof(uint32_t);
    std::array<uint32_t, kCount> src{};
    for (uint32_t i = 0; i < kCount; ++i) src[i] = 0xDEAD0000u | i;

    // Storage buffer on the GPU side (what a page would write into).
    WGPUBufferDescriptor gpuDesc{};
    gpuDesc.label = {"probe gpu buf", WGPU_STRLEN};
    gpuDesc.size  = kBytes;
    gpuDesc.usage = WGPUBufferUsage_Storage | WGPUBufferUsage_CopySrc | WGPUBufferUsage_CopyDst;
    auto gpuBuf = wgpuDeviceCreateBuffer(g.device, &gpuDesc);

    // Readback buffer on the CPU-visible side.
    WGPUBufferDescriptor rbDesc{};
    rbDesc.label = {"probe rb", WGPU_STRLEN};
    rbDesc.size  = kBytes;
    rbDesc.usage = WGPUBufferUsage_CopyDst | WGPUBufferUsage_MapRead;
    auto rbBuf = wgpuDeviceCreateBuffer(g.device, &rbDesc);

    if (!gpuBuf || !rbBuf) {
        o.detail = "createBuffer returned null";
        if (gpuBuf) wgpuBufferRelease(gpuBuf);
        if (rbBuf)  wgpuBufferRelease(rbBuf);
        return o;
    }

    wgpuQueueWriteBuffer(g.queue, gpuBuf, 0, src.data(), kBytes);

    auto enc = wgpuDeviceCreateCommandEncoder(g.device, nullptr);
    wgpuCommandEncoderCopyBufferToBuffer(enc, gpuBuf, 0, rbBuf, 0, kBytes);
    auto cb = wgpuCommandEncoderFinish(enc, nullptr);
    wgpuCommandEncoderRelease(enc);
    wgpuQueueSubmit(g.queue, 1, &cb);
    wgpuCommandBufferRelease(cb);

    MapState ms;
    WGPUBufferMapCallbackInfo cbi{};
    cbi.nextInChain = nullptr;
    cbi.mode      = WGPUCallbackMode_AllowProcessEvents;
    cbi.callback  = onMapped;
    cbi.userdata1 = &ms;
    cbi.userdata2 = nullptr;
    wgpuBufferMapAsync(rbBuf, WGPUMapMode_Read, 0, kBytes, cbi);

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(3);
    while (!ms.done) {
        wgpuInstanceProcessEvents(g.instance);
        if (ms.done) break;
        if (std::chrono::steady_clock::now() > deadline) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    std::string detail;
    bool mapOk = ms.done && ms.status == WGPUMapAsyncStatus_Success;
    uint32_t mismatchIndex = static_cast<uint32_t>(-1);

    if (mapOk) {
        auto* mapped = static_cast<const uint32_t*>(
            wgpuBufferGetConstMappedRange(rbBuf, 0, kBytes));
        if (!mapped) {
            mapOk = false;
            detail = "getConstMappedRange null";
        } else {
            for (uint32_t i = 0; i < kCount; ++i) {
                if (mapped[i] != src[i]) { mismatchIndex = i; mapOk = false; break; }
            }
            if (mapOk) detail = "ok (" + std::to_string(kCount) + " u32 roundtrip)";
            else       detail = "mismatch at index " + std::to_string(mismatchIndex);
            wgpuBufferUnmap(rbBuf);
        }
    } else {
        detail = ms.done
            ? (std::string{"mapAsync failed: "} + ms.message)
            : std::string{"mapAsync timed out"};
    }

    uint64_t initialSize = wgpuBufferGetSize(rbBuf);
    uint64_t getSize     = wgpuBufferGetSize(rbBuf);

    char buf[512];
    std::snprintf(buf, sizeof(buf),
        "\"bytesRoundTripped\": %llu, "
        "\"mapAsyncStatus\": %u, "
        "\"mismatchIndex\": %lld, "
        "\"bufferGetSize\": %llu, "
        "\"bufferGetInitialSize\": %llu",
        static_cast<unsigned long long>(mapOk ? kBytes : 0),
        static_cast<unsigned>(ms.status),
        static_cast<long long>(mapOk ? -1 : mismatchIndex),
        static_cast<unsigned long long>(getSize),
        static_cast<unsigned long long>(initialSize));
    o.jsonBody = buf;

    wgpuBufferRelease(rbBuf);
    wgpuBufferRelease(gpuBuf);

    o.ok = mapOk;
    o.detail = detail;
    return o;
}

} // namespace webgpu_host
