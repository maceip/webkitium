// AdapterInfo + DeviceInfo probes.
//
// Produces the authoritative record of what the browser will see from
// GPUAdapter::info, GPUAdapter::features, GPUAdapter::limits on this Dawn
// build. When GPUDevice::features / GPUDevice::limits reach the JS layer,
// they come from these same entry points.
//
// Mapped WebCore files:
//   Source/WebCore/Modules/WebGPU/GPUAdapter.cpp            (info/features/limits forwarding)
//   Source/WebCore/Modules/WebGPU/GPUAdapterInfo.cpp        (string fields)
//   Source/WebCore/Modules/WebGPU/Implementation/WebGPUAdapterImpl.cpp (adapter native-side)
//   Source/WebCore/Modules/WebGPU/Implementation/WebGPUDeviceImpl.cpp  (device native-side)

#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

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

const char* adapterTypeName(WGPUAdapterType t) {
    switch (t) {
    case WGPUAdapterType_DiscreteGPU:   return "DiscreteGPU";
    case WGPUAdapterType_IntegratedGPU: return "IntegratedGPU";
    case WGPUAdapterType_CPU:           return "CPU";
    default:                            return "Unknown";
    }
}

const char* featureName(WGPUFeatureName f) {
    switch (f) {
    case WGPUFeatureName_DepthClipControl:          return "depth-clip-control";
    case WGPUFeatureName_Depth32FloatStencil8:      return "depth32float-stencil8";
    case WGPUFeatureName_TimestampQuery:            return "timestamp-query";
    case WGPUFeatureName_TextureCompressionBC:      return "texture-compression-bc";
    case WGPUFeatureName_TextureCompressionETC2:    return "texture-compression-etc2";
    case WGPUFeatureName_TextureCompressionASTC:    return "texture-compression-astc";
    case WGPUFeatureName_IndirectFirstInstance:     return "indirect-first-instance";
    case WGPUFeatureName_ShaderF16:                 return "shader-f16";
    case WGPUFeatureName_RG11B10UfloatRenderable:   return "rg11b10ufloat-renderable";
    case WGPUFeatureName_BGRA8UnormStorage:         return "bgra8unorm-storage";
    case WGPUFeatureName_Float32Filterable:         return "float32-filterable";
    default:                                        return "other";
    }
}

std::string toStr(WGPUStringView v) {
    if (!v.data) return {};
    if (v.length == WGPU_STRLEN) return std::string{v.data};
    return std::string{v.data, v.length};
}

std::string jsonEscape(std::string_view s) {
    std::string out; out.reserve(s.size() + 2);
    out.push_back('"');
    for (char c : s) {
        switch (c) {
        case '"':  out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n";  break;
        case '\r': out += "\\r";  break;
        default:
            if (static_cast<unsigned char>(c) < 0x20) {
                char buf[8]; std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                out += buf;
            } else out.push_back(c);
        }
    }
    out.push_back('"');
    return out;
}

std::string collectFeatures(WGPUSupportedFeatures& feats) {
    std::string out = "[";
    for (size_t i = 0; i < feats.featureCount; ++i) {
        if (i) out += ", ";
        out += jsonEscape(featureName(feats.features[i]));
    }
    out += "]";
    return out;
}

std::string limitsJson(const WGPULimits& L) {
    char buf[2048];
    std::snprintf(buf, sizeof(buf),
        "{"
        "\"maxTextureDimension1D\": %u, "
        "\"maxTextureDimension2D\": %u, "
        "\"maxTextureDimension3D\": %u, "
        "\"maxTextureArrayLayers\": %u, "
        "\"maxBindGroups\": %u, "
        "\"maxBindingsPerBindGroup\": %u, "
        "\"maxDynamicUniformBuffersPerPipelineLayout\": %u, "
        "\"maxDynamicStorageBuffersPerPipelineLayout\": %u, "
        "\"maxSampledTexturesPerShaderStage\": %u, "
        "\"maxSamplersPerShaderStage\": %u, "
        "\"maxStorageBuffersPerShaderStage\": %u, "
        "\"maxStorageTexturesPerShaderStage\": %u, "
        "\"maxUniformBuffersPerShaderStage\": %u, "
        "\"maxUniformBufferBindingSize\": %llu, "
        "\"maxStorageBufferBindingSize\": %llu, "
        "\"minUniformBufferOffsetAlignment\": %u, "
        "\"minStorageBufferOffsetAlignment\": %u, "
        "\"maxVertexBuffers\": %u, "
        "\"maxBufferSize\": %llu, "
        "\"maxVertexAttributes\": %u, "
        "\"maxVertexBufferArrayStride\": %u, "
        "\"maxInterStageShaderVariables\": %u, "
        "\"maxColorAttachments\": %u, "
        "\"maxColorAttachmentBytesPerSample\": %u, "
        "\"maxComputeWorkgroupStorageSize\": %u, "
        "\"maxComputeInvocationsPerWorkgroup\": %u, "
        "\"maxComputeWorkgroupSizeX\": %u, "
        "\"maxComputeWorkgroupSizeY\": %u, "
        "\"maxComputeWorkgroupSizeZ\": %u, "
        "\"maxComputeWorkgroupsPerDimension\": %u"
        "}",
        L.maxTextureDimension1D, L.maxTextureDimension2D, L.maxTextureDimension3D,
        L.maxTextureArrayLayers, L.maxBindGroups, L.maxBindingsPerBindGroup,
        L.maxDynamicUniformBuffersPerPipelineLayout,
        L.maxDynamicStorageBuffersPerPipelineLayout,
        L.maxSampledTexturesPerShaderStage, L.maxSamplersPerShaderStage,
        L.maxStorageBuffersPerShaderStage, L.maxStorageTexturesPerShaderStage,
        L.maxUniformBuffersPerShaderStage,
        static_cast<unsigned long long>(L.maxUniformBufferBindingSize),
        static_cast<unsigned long long>(L.maxStorageBufferBindingSize),
        L.minUniformBufferOffsetAlignment, L.minStorageBufferOffsetAlignment,
        L.maxVertexBuffers,
        static_cast<unsigned long long>(L.maxBufferSize),
        L.maxVertexAttributes, L.maxVertexBufferArrayStride,
        L.maxInterStageShaderVariables,
        L.maxColorAttachments, L.maxColorAttachmentBytesPerSample,
        L.maxComputeWorkgroupStorageSize, L.maxComputeInvocationsPerWorkgroup,
        L.maxComputeWorkgroupSizeX, L.maxComputeWorkgroupSizeY,
        L.maxComputeWorkgroupSizeZ, L.maxComputeWorkgroupsPerDimension);
    return buf;
}

} // namespace

ProbeOutcome probeAdapterInfo(const GpuBootstrap& g) {
    ProbeOutcome o; o.name = "adapterInfo";
    if (!g.adapter) { o.detail = "no adapter"; return o; }

    WGPUAdapterInfo info{};
    if (wgpuAdapterGetInfo(g.adapter, &info) != WGPUStatus_Success) {
        o.detail = "wgpuAdapterGetInfo failed";
        return o;
    }

    WGPULimits limits{};
    const bool haveLimits = (wgpuAdapterGetLimits(g.adapter, &limits) == WGPUStatus_Success);

    WGPUSupportedFeatures feats{};
    wgpuAdapterGetFeatures(g.adapter, &feats);

    char buf[4096];
    std::snprintf(buf, sizeof(buf),
        "\"backend\": %s, "
        "\"adapterType\": %s, "
        "\"vendor\": %s, "
        "\"architecture\": %s, "
        "\"device\": %s, "
        "\"description\": %s, "
        "\"vendorId\": %u, "
        "\"deviceId\": %u, "
        "\"features\": %s, "
        "\"limits\": %s",
        jsonEscape(backendName(info.backendType)).c_str(),
        jsonEscape(adapterTypeName(info.adapterType)).c_str(),
        jsonEscape(toStr(info.vendor)).c_str(),
        jsonEscape(toStr(info.architecture)).c_str(),
        jsonEscape(toStr(info.device)).c_str(),
        jsonEscape(toStr(info.description)).c_str(),
        info.vendorID, info.deviceID,
        collectFeatures(feats).c_str(),
        haveLimits ? limitsJson(limits).c_str() : "null");
    o.jsonBody = buf;

    wgpuAdapterInfoFreeMembers(info);
    wgpuSupportedFeaturesFreeMembers(feats);

    o.ok = true;
    o.detail = "ok";
    return o;
}

ProbeOutcome probeDeviceInfo(const GpuBootstrap& g) {
    ProbeOutcome o; o.name = "deviceInfo";
    if (!g.device) { o.detail = "no device"; return o; }

    WGPULimits limits{};
    const bool haveLimits = (wgpuDeviceGetLimits(g.device, &limits) == WGPUStatus_Success);

    WGPUSupportedFeatures feats{};
    wgpuDeviceGetFeatures(g.device, &feats);

    char buf[4096];
    std::snprintf(buf, sizeof(buf),
        "\"features\": %s, "
        "\"limits\": %s, "
        "\"queueAvailable\": %s",
        collectFeatures(feats).c_str(),
        haveLimits ? limitsJson(limits).c_str() : "null",
        g.queue ? "true" : "false");
    o.jsonBody = buf;

    wgpuSupportedFeaturesFreeMembers(feats);

    o.ok = g.queue != nullptr && haveLimits;
    o.detail = o.ok ? "ok" : "missing queue or limits";
    return o;
}

} // namespace webgpu_host
