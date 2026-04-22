// Milestone-3 demo scene: a ball bouncing in a window.
//
// CPU side:
//   - one uniform buffer (ball position, radius, aspect, time, colors)
//   - position/velocity integrated on each tick() call (the rAF equivalent)
//
// GPU side:
//   - one render pipeline drawing a full-screen triangle
//   - fragment shader is an SDF circle with a soft shadow under the ball
//
// This touches exactly the Dawn entry points Modules/WebGPU/Implementation
// needs to implement on Windows for canvas rendering: buffer create,
// queueWriteBuffer, shader module, render pipeline, command encoder,
// beginRenderPass, setPipeline, setBindGroup, draw, finish, queue.submit.

#include "webgpu_host/Host.h"

#include <webgpu/webgpu.h>

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>

namespace webgpu_host {
namespace {

struct Uniforms {
    float ball[4]   = {0.0f, 0.0f, 0.15f, 0.0f};   // x, y, radius, time
    float view[4]   = {1.0f, 1.0f, 0.0f, 0.0f};    // aspect, 1/aspect, 0, 0
    float bg[4]     = {0.08f, 0.09f, 0.12f, 1.0f};
    float fg[4]     = {0.95f, 0.55f, 0.35f, 1.0f};
};

const char* kShader = R"WGSL(
struct Uniforms {
  ball : vec4<f32>,
  view : vec4<f32>,
  bg   : vec4<f32>,
  fg   : vec4<f32>,
};
@group(0) @binding(0) var<uniform> u : Uniforms;

struct VSOut {
  @builtin(position) pos : vec4<f32>,
  @location(0) ndc : vec2<f32>,
};

@vertex
fn vs(@builtin(vertex_index) vi : u32) -> VSOut {
  // Full-screen triangle. Vertices in clip space: (-1,-3), (3,1), (-1,1).
  var positions = array<vec2<f32>, 3>(
    vec2<f32>(-1.0, -3.0),
    vec2<f32>( 3.0,  1.0),
    vec2<f32>(-1.0,  1.0)
  );
  var out : VSOut;
  let p = positions[vi];
  out.pos = vec4<f32>(p, 0.0, 1.0);
  out.ndc = p;
  return out;
}

@fragment
fn fs(in : VSOut) -> @location(0) vec4<f32> {
  let aspect = u.view.x;
  let pos = vec2<f32>(in.ndc.x * aspect, in.ndc.y);
  let center = vec2<f32>(u.ball.x * aspect, u.ball.y);
  let r = u.ball.z;

  let d = length(pos - center) - r;
  let ballMask = 1.0 - smoothstep(0.0, 0.006, d);

  // Floor shadow (darker ellipse under current x).
  let floorY = -0.92;
  let shadowD = length(vec2<f32>(pos.x - center.x, (pos.y - floorY) * 3.0)) - r * 0.65;
  let shadow = 1.0 - smoothstep(0.0, 0.04, shadowD);

  // Simple rim shading using inverse distance inside ball.
  let rim = clamp(1.0 - (-d) / r, 0.0, 1.0);
  let ballColor = mix(u.fg.rgb, u.fg.rgb * 0.55, rim);

  var color = u.bg.rgb;
  color = mix(color, vec3<f32>(0.0), shadow * 0.35);
  color = mix(color, ballColor, ballMask);
  return vec4<f32>(color, 1.0);
}
)WGSL";

class BouncingBallScene final : public Scene {
public:
    const char* name() const override { return "ball"; }

    bool init(WGPUDevice device, WGPUTextureFormat colorFormat) override {
        m_device      = device;
        m_colorFormat = colorFormat;
        m_queue       = wgpuDeviceGetQueue(device);

        if (!createUniformBuffer())         return false;
        if (!createShaderModule())          return false;
        if (!createBindGroupLayout())       return false;
        if (!createPipelineLayout())        return false;
        if (!createPipeline())              return false;
        if (!createBindGroup())             return false;
        return true;
    }

    void resize(uint32_t w, uint32_t h) override {
        m_width  = w ? w : 1;
        m_height = h ? h : 1;
    }

    void tick(const SceneContext& ctx, WGPUTextureView colorView) override {
        advanceBall(ctx.dtSeconds);

        Uniforms u;
        u.ball[0] = m_x;
        u.ball[1] = m_y;
        u.ball[2] = m_radius;
        u.ball[3] = static_cast<float>(ctx.tSeconds);
        const float aspect = static_cast<float>(ctx.width) / static_cast<float>(ctx.height);
        u.view[0] = aspect;
        u.view[1] = 1.0f / aspect;
        wgpuQueueWriteBuffer(ctx.queue, m_uniformBuffer, 0, &u, sizeof(u));

        WGPUCommandEncoderDescriptor encDesc{};
        encDesc.label = {"frame", WGPU_STRLEN};
        auto encoder = wgpuDeviceCreateCommandEncoder(ctx.device, &encDesc);

        WGPURenderPassColorAttachment colorAtt{};
        colorAtt.view       = colorView;
        colorAtt.loadOp     = WGPULoadOp_Clear;
        colorAtt.storeOp    = WGPUStoreOp_Store;
        colorAtt.clearValue = {0.08, 0.09, 0.12, 1.0};
        colorAtt.depthSlice = WGPU_DEPTH_SLICE_UNDEFINED;

        WGPURenderPassDescriptor passDesc{};
        passDesc.label                  = {"ball-pass", WGPU_STRLEN};
        passDesc.colorAttachmentCount   = 1;
        passDesc.colorAttachments       = &colorAtt;
        passDesc.depthStencilAttachment = nullptr;

        auto pass = wgpuCommandEncoderBeginRenderPass(encoder, &passDesc);
        wgpuRenderPassEncoderSetPipeline(pass, m_pipeline);
        wgpuRenderPassEncoderSetBindGroup(pass, 0, m_bindGroup, 0, nullptr);
        wgpuRenderPassEncoderDraw(pass, 3, 1, 0, 0);
        wgpuRenderPassEncoderEnd(pass);
        wgpuRenderPassEncoderRelease(pass);

        auto cb = wgpuCommandEncoderFinish(encoder, nullptr);
        wgpuCommandEncoderRelease(encoder);
        wgpuQueueSubmit(ctx.queue, 1, &cb);
        wgpuCommandBufferRelease(cb);
    }

    ~BouncingBallScene() override { destroy(); }

private:
    void destroy() {
        if (m_bindGroup)        wgpuBindGroupRelease(m_bindGroup);
        if (m_pipeline)         wgpuRenderPipelineRelease(m_pipeline);
        if (m_pipelineLayout)   wgpuPipelineLayoutRelease(m_pipelineLayout);
        if (m_bindGroupLayout)  wgpuBindGroupLayoutRelease(m_bindGroupLayout);
        if (m_shader)           wgpuShaderModuleRelease(m_shader);
        if (m_uniformBuffer)    wgpuBufferRelease(m_uniformBuffer);
        if (m_queue)            wgpuQueueRelease(m_queue);
    }

    bool createUniformBuffer() {
        WGPUBufferDescriptor desc{};
        desc.label = {"ball uniforms", WGPU_STRLEN};
        desc.size  = sizeof(Uniforms);
        desc.usage = WGPUBufferUsage_Uniform | WGPUBufferUsage_CopyDst;
        desc.mappedAtCreation = 0;
        m_uniformBuffer = wgpuDeviceCreateBuffer(m_device, &desc);
        return m_uniformBuffer != nullptr;
    }

    bool createShaderModule() {
        WGPUShaderSourceWGSL src{};
        src.chain.next = nullptr;
        src.chain.sType = WGPUSType_ShaderSourceWGSL;
        src.code = {kShader, WGPU_STRLEN};
        WGPUShaderModuleDescriptor desc{};
        desc.nextInChain = &src.chain;
        desc.label = {"ball shader", WGPU_STRLEN};
        m_shader = wgpuDeviceCreateShaderModule(m_device, &desc);
        return m_shader != nullptr;
    }

    bool createBindGroupLayout() {
        WGPUBindGroupLayoutEntry entry{};
        entry.binding = 0;
        entry.visibility = WGPUShaderStage_Fragment | WGPUShaderStage_Vertex;
        entry.buffer.type = WGPUBufferBindingType_Uniform;
        entry.buffer.minBindingSize = sizeof(Uniforms);

        WGPUBindGroupLayoutDescriptor desc{};
        desc.label = {"ball bgl", WGPU_STRLEN};
        desc.entryCount = 1;
        desc.entries = &entry;
        m_bindGroupLayout = wgpuDeviceCreateBindGroupLayout(m_device, &desc);
        return m_bindGroupLayout != nullptr;
    }

    bool createPipelineLayout() {
        WGPUPipelineLayoutDescriptor desc{};
        desc.label = {"ball layout", WGPU_STRLEN};
        desc.bindGroupLayoutCount = 1;
        desc.bindGroupLayouts = &m_bindGroupLayout;
        m_pipelineLayout = wgpuDeviceCreatePipelineLayout(m_device, &desc);
        return m_pipelineLayout != nullptr;
    }

    bool createPipeline() {
        WGPUColorTargetState colorTarget{};
        colorTarget.format = m_colorFormat;
        colorTarget.writeMask = WGPUColorWriteMask_All;
        WGPUBlendState blend{};
        blend.color = {WGPUBlendOperation_Add, WGPUBlendFactor_One, WGPUBlendFactor_Zero};
        blend.alpha = {WGPUBlendOperation_Add, WGPUBlendFactor_One, WGPUBlendFactor_Zero};
        colorTarget.blend = &blend;

        WGPUFragmentState frag{};
        frag.module = m_shader;
        frag.entryPoint = {"fs", WGPU_STRLEN};
        frag.targetCount = 1;
        frag.targets = &colorTarget;

        WGPURenderPipelineDescriptor desc{};
        desc.label = {"ball pipeline", WGPU_STRLEN};
        desc.layout = m_pipelineLayout;
        desc.vertex.module = m_shader;
        desc.vertex.entryPoint = {"vs", WGPU_STRLEN};
        desc.vertex.bufferCount = 0;
        desc.vertex.buffers = nullptr;
        desc.primitive.topology = WGPUPrimitiveTopology_TriangleList;
        desc.primitive.cullMode = WGPUCullMode_None;
        desc.primitive.frontFace = WGPUFrontFace_CCW;
        desc.multisample.count = 1;
        desc.multisample.mask = 0xFFFFFFFF;
        desc.fragment = &frag;

        m_pipeline = wgpuDeviceCreateRenderPipeline(m_device, &desc);
        return m_pipeline != nullptr;
    }

    bool createBindGroup() {
        WGPUBindGroupEntry entry{};
        entry.binding = 0;
        entry.buffer = m_uniformBuffer;
        entry.size = sizeof(Uniforms);

        WGPUBindGroupDescriptor desc{};
        desc.label = {"ball bind group", WGPU_STRLEN};
        desc.layout = m_bindGroupLayout;
        desc.entryCount = 1;
        desc.entries = &entry;
        m_bindGroup = wgpuDeviceCreateBindGroup(m_device, &desc);
        return m_bindGroup != nullptr;
    }

    void advanceBall(double dt) {
        // Integrate with gravity; bounce on walls and floor.
        const float g       = -2.0f;              // NDC units / s^2
        const float damping = 0.85f;
        m_vy += g * static_cast<float>(dt);
        m_x  += m_vx * static_cast<float>(dt);
        m_y  += m_vy * static_cast<float>(dt);

        const float left = -1.0f + m_radius;
        const float right = 1.0f - m_radius;
        const float floor = -1.0f + m_radius;

        if (m_x < left)  { m_x = left;  m_vx = std::fabs(m_vx); }
        if (m_x > right) { m_x = right; m_vx = -std::fabs(m_vx); }
        if (m_y < floor) {
            m_y = floor;
            m_vy = std::fabs(m_vy) * damping;
            // Stop tiny jitter.
            if (std::fabs(m_vy) < 0.25f) m_vy = 1.6f;   // kick back up
        }
    }

    WGPUDevice           m_device          = nullptr;
    WGPUQueue            m_queue           = nullptr;
    WGPUTextureFormat    m_colorFormat     = WGPUTextureFormat_BGRA8Unorm;
    WGPUBuffer           m_uniformBuffer   = nullptr;
    WGPUShaderModule     m_shader          = nullptr;
    WGPUBindGroupLayout  m_bindGroupLayout = nullptr;
    WGPUPipelineLayout   m_pipelineLayout  = nullptr;
    WGPURenderPipeline   m_pipeline        = nullptr;
    WGPUBindGroup        m_bindGroup       = nullptr;

    uint32_t m_width = 1, m_height = 1;
    float m_x = -0.5f, m_y = 0.7f;
    float m_vx = 0.6f, m_vy = 0.0f;
    float m_radius = 0.12f;
};

} // namespace

std::unique_ptr<Scene> createBouncingBallScene() {
    return std::make_unique<BouncingBallScene>();
}

} // namespace webgpu_host
