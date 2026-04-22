// Dispatcher for --suite.

#include "webgpu_host/Probes.h"

#include <string_view>
#include <vector>

namespace webgpu_host {

uint32_t parseProbeMask(std::string_view names, std::string& err) {
    if (names.empty() || names == "all") return toMask(ProbeId::All);

    uint32_t mask = 0;
    size_t i = 0;
    while (i < names.size()) {
        size_t j = names.find(',', i);
        if (j == std::string_view::npos) j = names.size();
        std::string_view n = names.substr(i, j - i);
        if      (n == "adapter")       mask |= toMask(ProbeId::AdapterInfo);
        else if (n == "device")        mask |= toMask(ProbeId::DeviceInfo);
        else if (n == "buffer")        mask |= toMask(ProbeId::BufferReadback);
        else if (n == "compute")       mask |= toMask(ProbeId::ComputeSmoke);
        else if (n == "errors")        mask |= toMask(ProbeId::ErrorCallback);
        else if (n == "surface")       mask |= toMask(ProbeId::SurfaceRoundtrip);
        else if (n == "render")        mask |= toMask(ProbeId::RenderOffscreen);
        else if (n == "all")           mask |= toMask(ProbeId::All);
        else {
            err = "unknown probe: ";
            err.append(n);
            return 0;
        }
        i = j + 1;
    }
    return mask;
}

std::vector<ProbeOutcome> runProbeSuite(GpuBootstrap& g,
                                        SurfaceBinding* surf,
                                        uint32_t mask) {
    std::vector<ProbeOutcome> out;
    if (mask & toMask(ProbeId::AdapterInfo))    out.push_back(probeAdapterInfo(g));
    if (mask & toMask(ProbeId::DeviceInfo))     out.push_back(probeDeviceInfo(g));
    if (mask & toMask(ProbeId::BufferReadback)) out.push_back(probeBufferReadback(g));
    if (mask & toMask(ProbeId::ComputeSmoke))   out.push_back(probeComputeSmoke(g));
    if (mask & toMask(ProbeId::ErrorCallback))  out.push_back(probeErrorCallback(g));
    if (mask & toMask(ProbeId::SurfaceRoundtrip) && surf && surf->configured)
        out.push_back(probeSurfaceRoundtrip(g, *surf));
    if (mask & toMask(ProbeId::RenderOffscreen)) out.push_back(probeRenderOffscreen(g));
    return out;
}

} // namespace webgpu_host
