// Probes that exercise the subset of Dawn's native API that
// WebCore::WebGPU::* actually calls on Windows. Each probe returns a
// JSON-ready result; the lane treats the merged report as the authoritative
// record of what Dawn + D3D12 delivers on a given host + vcpkg pin.
//
// Every probe maps to a specific WebCore file (see docs/INTEGRATION.md).
// Failing probes point at concrete in-tree work: "patch X, because Dawn
// does Y on Windows."

#pragma once

#include "webgpu_host/Host.h"

#include <string>
#include <vector>

namespace webgpu_host {

struct ProbeOutcome {
    std::string name;
    bool ok = false;
    std::string detail;        // one-line human status
    std::string jsonBody;      // pre-formatted JSON object contents (no braces)
};

enum class ProbeId : uint32_t {
    AdapterInfo     = 1u << 0,  // Modules/WebGPU/GPUAdapter.cpp, GPUAdapterInfo.cpp
    DeviceInfo      = 1u << 1,  // Modules/WebGPU/GPUDevice.cpp
    BufferReadback  = 1u << 2,  // Implementation/WebGPUQueueImpl.cpp writeBuffer + mapAsync
    ComputeSmoke    = 1u << 3,  // patches/windows/0015-0019 exercise this
    ErrorCallback   = 1u << 4,  // Implementation/WebGPUDeviceImpl.cpp uncapturedErrorCallback
    SurfaceRoundtrip= 1u << 5,  // Implementation/WebGPUImpl.cpp createPresentationContext
    RenderOffscreen = 1u << 6,  // helloTriangle/rotatingCube shape, offscreen
    All             = 0xFFFFFFFFu
};

constexpr uint32_t toMask(ProbeId id) { return static_cast<uint32_t>(id); }

// Individual probes. They assume a successfully-bootstrapped GPU.
ProbeOutcome probeAdapterInfo(const GpuBootstrap&);
ProbeOutcome probeDeviceInfo(const GpuBootstrap&);
ProbeOutcome probeBufferReadback(const GpuBootstrap&);
ProbeOutcome probeComputeSmoke(const GpuBootstrap&);
ProbeOutcome probeErrorCallback(GpuBootstrap&);                 // mutates lastError
ProbeOutcome probeSurfaceRoundtrip(const GpuBootstrap&,
                                   const SurfaceBinding&);       // configures + one frame
ProbeOutcome probeRenderOffscreen(const GpuBootstrap&);           // samples shape, no HWND

std::vector<ProbeOutcome> runProbeSuite(GpuBootstrap&,
                                        SurfaceBinding*,         // nullable
                                        uint32_t mask);

// Parse "adapter,device,compute" etc.; returns 0 on unknown name.
uint32_t parseProbeMask(std::string_view names, std::string& err);

} // namespace webgpu_host
