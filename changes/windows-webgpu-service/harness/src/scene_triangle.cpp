// Minimal-possible scene: clear + one triangle.
// If this doesn't render, the issue is in surface/configure/present plumbing,
// not in the bouncing-ball app logic. Keep as a bisection tool.

#include "webgpu_host/Host.h"

#include <webgpu/webgpu.h>

#include <memory>

namespace webgpu_host {
namespace {

const char* kShader = R"WGSL(
@vertex
fn vs(@builtin(vertex_index) vi : u32) -> @builtin(position) vec4<f32> {
  var p = array<vec2<f32>, 3>(
    vec2<f32>( 0.0,  0.6),
    vec2<f32>(-0.6, -0.5),
    vec2<f32>( 0.6, -0.5)
  );
  return vec4<f32>(p[vi], 0.0, 1.0);
}
@fragment
fn fs() -> @location(0) vec4<f32> {
  return vec4<f32>(0.35, 0.85, 0.55, 1.0);
}
)WGSL";

class TriangleScene final : public Scene {
public:
    const char* name() const override { return "triangle"; }

    bool init(WGPUDevice device, WGPUTextureFormat colorFormat) override {
        m_device = device;

        WGPUShaderSourceWGSL src{};
        src.chain.next  = nullptr;
        src.chain.sType = WGPUSType_ShaderSourceWGSL;
        src.code        = {kShader, WGPU_STRLEN};
        WGPUShaderModuleDescriptor sDesc{};
        sDesc.nextInChain = &src.chain;
        sDesc.label       = {"triangle shader", WGPU_STRLEN};
        m_shader = wgpuDeviceCreateShaderModule(device, &sDesc);
        if (!m_shader) return false;

        WGPUColorTargetState target{};
        target.format    = colorFormat;
        target.writeMask = WGPUColorWriteMask_All;

        WGPUFragmentState frag{};
        frag.module     = m_shader;
        frag.entryPoint = {"fs", WGPU_STRLEN};
        frag.targetCount = 1;
        frag.targets = &target;

        WGPURenderPipelineDescriptor desc{};
        desc.label = {"triangle pipeline", WGPU_STRLEN};
        desc.layout = nullptr;                  // auto-layout
        desc.vertex.module = m_shader;
        desc.vertex.entryPoint = {"vs", WGPU_STRLEN};
        desc.primitive.topology = WGPUPrimitiveTopology_TriangleList;
        desc.primitive.cullMode = WGPUCullMode_None;
        desc.primitive.frontFace = WGPUFrontFace_CCW;
        desc.multisample.count = 1;
        desc.multisample.mask  = 0xFFFFFFFF;
        desc.fragment = &frag;

        m_pipeline = wgpuDeviceCreateRenderPipeline(device, &desc);
        return m_pipeline != nullptr;
    }

    void resize(uint32_t, uint32_t) override {}

    void tick(const SceneContext& ctx, WGPUTextureView colorView) override {
        WGPUCommandEncoderDescriptor encDesc{};
        encDesc.label = {"tri-frame", WGPU_STRLEN};
        auto encoder = wgpuDeviceCreateCommandEncoder(ctx.device, &encDesc);

        WGPURenderPassColorAttachment att{};
        att.view       = colorView;
        att.loadOp     = WGPULoadOp_Clear;
        att.storeOp    = WGPUStoreOp_Store;
        att.clearValue = {0.05, 0.08, 0.12, 1.0};
        att.depthSlice = WGPU_DEPTH_SLICE_UNDEFINED;

        WGPURenderPassDescriptor passDesc{};
        passDesc.colorAttachmentCount = 1;
        passDesc.colorAttachments     = &att;
        auto pass = wgpuCommandEncoderBeginRenderPass(encoder, &passDesc);
        wgpuRenderPassEncoderSetPipeline(pass, m_pipeline);
        wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpuRenderPassEncoderEnd(pass);
        wgpuRenderPassEncoderRelease(pass);

        auto cb = wgpuCommandEncoderFinish(encoder, nullptr);
        wgpuCommandEncoderRelease(encoder);
        wgpuQueueSubmit(ctx.queue, 1, &cb);
        wgpuCommandBufferRelease(cb);
    }

    ~TriangleScene() override {
        if (m_pipeline) wgpuRenderPipelineRelease(m_pipeline);
        if (m_shader)   wgpuShaderModuleRelease(m_shader);
    }

private:
    WGPUDevice          m_device   = nullptr;
    WGPUShaderModule    m_shader   = nullptr;
    WGPURenderPipeline  m_pipeline = nullptr;
};

} // namespace

std::unique_ptr<Scene> createTriangleScene() {
    return std::make_unique<TriangleScene>();
}

} // namespace webgpu_host
