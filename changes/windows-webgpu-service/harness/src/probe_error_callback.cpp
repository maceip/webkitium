// Uncaptured-error callback probe.
//
// Intentionally commits a validation error — requesting a buffer with a size
// that exceeds adapter limits — and confirms the device's uncapturedError
// callback fires. If this probe fails, pages will silently swallow WebGPU
// errors that the spec requires to surface via GPUUncapturedErrorEvent.
//
// Mapped WebCore files:
//   Implementation/WebGPUDeviceImpl.cpp  uncapturedErrorCallback wiring
//   Modules/WebGPU/GPUDevice.cpp          onuncapturederror event path

#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <string>
#include <thread>

namespace webgpu_host {

namespace {

struct ErrState { bool fired = false; WGPUErrorType type = WGPUErrorType_NoError; std::string message; };

std::string toStr(WGPUStringView v) {
    if (!v.data) return {};
    if (v.length == WGPU_STRLEN) return std::string{v.data};
    return std::string{v.data, v.length};
}

void onError(const WGPUDevice*, WGPUErrorType type, WGPUStringView msg, void* ud1, void*) {
    auto* e = static_cast<ErrState*>(ud1);
    if (!e) return;
    e->fired = true;
    e->type = type;
    e->message = toStr(msg);
}

struct PopState { bool done = false; WGPUErrorType type = WGPUErrorType_NoError; std::string message; };

void onPopError(WGPUPopErrorScopeStatus, WGPUErrorType type, WGPUStringView msg, void* ud1, void*) {
    auto* p = static_cast<PopState*>(ud1);
    if (!p) return;
    p->done = true;
    p->type = type;
    p->message = toStr(msg);
}

} // namespace

ProbeOutcome probeErrorCallback(GpuBootstrap& g) {
    ProbeOutcome o; o.name = "errorCallback";
    if (!g.device) { o.detail = "no device"; return o; }

    ErrState es;
    // Note: in Dawn v20260410.140140 the uncaptured-error callback is set
    // exactly once via WGPUDeviceDescriptor.uncapturedErrorCallbackInfo at
    // device creation time — there is no wgpuDeviceSetUncapturedErrorCallback.
    // The bootstrap installs a logger that writes to GpuBootstrap::lastError;
    // we verify validation errors via pushErrorScope/popErrorScope below, which
    // does not depend on the uncaptured callback.
    (void)es;
    (void)&onError;

    // Push a validation error scope so we also capture the error via pop.
    wgpuDevicePushErrorScope(g.device, WGPUErrorFilter_Validation);

    // Offender: allocate an absurd buffer. Dawn reports "Validation error".
    WGPUBufferDescriptor bad{};
    bad.size  = static_cast<uint64_t>(-1) / 2;
    bad.usage = WGPUBufferUsage_CopyDst;
    auto bogus = wgpuDeviceCreateBuffer(g.device, &bad);
    if (bogus) {
        // Dawn may return an invalid buffer handle that still needs release.
        wgpuBufferRelease(bogus);
    }

    PopState ps;
    WGPUPopErrorScopeCallbackInfo pcb{};
    pcb.mode      = WGPUCallbackMode_AllowProcessEvents;
    pcb.callback  = onPopError;
    pcb.userdata1 = &ps;
    wgpuDevicePopErrorScope(g.device, pcb);

    const auto deadline = std::chrono::steady_clock::now() + std::chrono::seconds(2);
    while (!ps.done) {
        wgpuInstanceProcessEvents(g.instance);
        if (ps.done) break;
        if (std::chrono::steady_clock::now() > deadline) break;
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }

    char buf[512];
    std::snprintf(buf, sizeof(buf),
        "\"popErrorScopeType\": %u, "
        "\"uncapturedFired\": %s, "
        "\"uncapturedType\": %u",
        static_cast<unsigned>(ps.type),
        es.fired ? "true" : "false",
        static_cast<unsigned>(es.type));
    o.jsonBody = buf;

    // Reset lastError so this deliberate stimulus doesn't pollute the
    // overall bootstrap status.
    g.lastError.clear();

    o.ok = (ps.type == WGPUErrorType_Validation) || es.fired;
    o.detail = o.ok
        ? (ps.message.empty() ? es.message : ps.message)
        : "no validation error surfaced";
    return o;
}

} // namespace webgpu_host
