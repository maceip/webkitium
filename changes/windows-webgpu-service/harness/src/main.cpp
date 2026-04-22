// WinMain + message loop for the Windows WebGPU harness.
//
// Pieces:
//   - CLI parse                  -> Config
//   - Win32 window               -> HWND to hand to Dawn surface
//   - Dawn bootstrap             -> instance, adapter, device, queue
//   - Attach + configure surface -> swapchain equivalent
//   - Scene init + per-frame tick (rAF-style)
//   - Optional probe JSON + exit
//
// The "rAF" here is driven by Windows messages + a high-resolution timer.
// That intentionally mirrors what the eventual in-tree Windows compositor tick
// will look like: one tick per displayed frame, one render pass, one submit,
// one surface present.

#include "webgpu_host/Host.h"
#include "webgpu_host/Probes.h"

#include <webgpu/webgpu.h>

#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

using namespace webgpu_host;

namespace {

constexpr wchar_t kClass[] = L"webgpu_host_window";

struct AppState {
    Config cfg;
    GpuBootstrap gpu;
    SurfaceBinding surf;
    std::unique_ptr<Scene> scene;
    HWND hwnd = nullptr;
    bool needsResize = false;
    bool closing = false;
    uint32_t framesSubmitted = 0;
    uint32_t framesPresented = 0;
    std::string lastRenderError;
};

LRESULT CALLBACK wndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    AppState* app = reinterpret_cast<AppState*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
    switch (msg) {
    case WM_SIZE:
        if (app) {
            uint32_t w = LOWORD(lp);
            uint32_t h = HIWORD(lp);
            if (w && h && (w != app->surf.width || h != app->surf.height)) {
                app->surf.width = w;
                app->surf.height = h;
                app->needsResize = true;
            }
        }
        return 0;
    case WM_CLOSE:
        if (app) app->closing = true;
        PostQuitMessage(0);
        return 0;
    case WM_ERASEBKGND:
        return 1; // skip; we paint every frame
    case WM_KEYDOWN:
        if (wp == VK_ESCAPE) {
            if (app) app->closing = true;
            PostQuitMessage(0);
        }
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

HWND createWindow(HINSTANCE hinst, const Config& cfg, AppState& app) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wc.lpfnWndProc = wndProc;
    wc.hInstance = hinst;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wc.lpszClassName = kClass;
    RegisterClassExW(&wc);

    RECT rc{0, 0, static_cast<LONG>(cfg.width), static_cast<LONG>(cfg.height)};
    DWORD style = WS_OVERLAPPEDWINDOW;
    AdjustWindowRect(&rc, style, FALSE);

    HWND hwnd = CreateWindowExW(0, kClass, L"webgpu_host - bouncing ball",
                                style,
                                CW_USEDEFAULT, CW_USEDEFAULT,
                                rc.right - rc.left, rc.bottom - rc.top,
                                nullptr, nullptr, hinst, nullptr);
    if (!hwnd) return nullptr;
    SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(&app));
    ShowWindow(hwnd, cfg.visible ? SW_SHOWDEFAULT : SW_HIDE);
    UpdateWindow(hwnd);
    return hwnd;
}

bool parseCli(int argc, wchar_t** argv, Config& cfg, std::string& err) {
    auto toUtf8 = [](const wchar_t* w) {
        int n = WideCharToMultiByte(CP_UTF8, 0, w, -1, nullptr, 0, nullptr, nullptr);
        std::string s(n ? n - 1 : 0, '\0');
        if (n) WideCharToMultiByte(CP_UTF8, 0, w, -1, s.data(), n, nullptr, nullptr);
        return s;
    };
    for (int i = 1; i < argc; ++i) {
        std::string a = toUtf8(argv[i]);
        auto next = [&](std::string& dst) -> bool {
            if (i + 1 >= argc) { err = a + " needs a value"; return false; }
            dst = toUtf8(argv[++i]);
            return true;
        };
        if (a == "--demo") {
            std::string v;
            if (!next(v)) return false;
            cfg.mode = Config::Mode::Demo;
            if (v == "ball") cfg.scene = Config::Scene::Ball;
            else if (v == "triangle") cfg.scene = Config::Scene::Triangle;
            else { err = "unknown --demo value: " + v; return false; }
        } else if (a == "--probe") {
            cfg.mode = Config::Mode::Probe;
            if (cfg.frameLimit == 0) cfg.frameLimit = 8;
        } else if (a == "--suite") {
            if (!next(cfg.suiteSpec)) return false;
        } else if (a == "--no-scene") {
            cfg.scene = Config::Scene::None;
        } else if (a == "--headless") {
            cfg.headless = true;
            cfg.visible = false;
        } else if (a == "--json") {
            if (!next(cfg.probeJsonPath)) return false;
        } else if (a == "--frames") {
            std::string v; if (!next(v)) return false;
            cfg.frameLimit = static_cast<uint32_t>(std::strtoul(v.c_str(), nullptr, 10));
        } else if (a == "--width") {
            std::string v; if (!next(v)) return false;
            cfg.width = static_cast<uint32_t>(std::strtoul(v.c_str(), nullptr, 10));
        } else if (a == "--height") {
            std::string v; if (!next(v)) return false;
            cfg.height = static_cast<uint32_t>(std::strtoul(v.c_str(), nullptr, 10));
        } else if (a == "--backend") {
            std::string v; if (!next(v)) return false;
            if      (v == "d3d12")     cfg.backendType = WGPUBackendType_D3D12;
            else if (v == "d3d11")     cfg.backendType = WGPUBackendType_D3D11;
            else if (v == "vulkan")    cfg.backendType = WGPUBackendType_Vulkan;
            else if (v == "undefined") cfg.backendType = WGPUBackendType_Undefined;
            else { err = "unknown --backend: " + v; return false; }
        } else if (a == "--timeout-ms") {
            std::string v; if (!next(v)) return false;
            cfg.pumpTimeout = std::chrono::milliseconds{std::strtoul(v.c_str(), nullptr, 10)};
        } else if (a == "--hidden") {
            cfg.visible = false;
        } else {
            err = "unknown arg: " + a;
            return false;
        }
    }
    return true;
}

void ensureConfigured(AppState& app) {
    if (app.needsResize) {
        configureSurface(app.gpu, app.surf);
        app.scene->resize(app.surf.width, app.surf.height);
        app.needsResize = false;
    }
}

bool renderOneFrame(AppState& app, double tSeconds, double dtSeconds) {
    ensureConfigured(app);

    WGPUTexture tex = nullptr;
    WGPUTextureView view = acquireColorView(app.surf, tex);
    if (!view) {
        // Most common cause: swapchain went stale; reconfigure next time.
        app.needsResize = true;
        return false;
    }

    SceneContext ctx{};
    ctx.device      = app.gpu.device;
    ctx.queue       = app.gpu.queue;
    ctx.colorFormat = app.surf.format;
    ctx.width       = app.surf.width;
    ctx.height      = app.surf.height;
    ctx.dtSeconds   = dtSeconds;
    ctx.tSeconds    = tSeconds;

    app.scene->tick(ctx, view);
    ++app.framesSubmitted;

    wgpuTextureViewRelease(view);

    wgpuSurfacePresent(app.surf.surface);
    if (tex) wgpuTextureRelease(tex);
    ++app.framesPresented;
    return true;
}

const char* backendString(WGPUBackendType b) {
    switch (b) {
    case WGPUBackendType_D3D11:  return "D3D11";
    case WGPUBackendType_D3D12:  return "D3D12";
    case WGPUBackendType_Vulkan: return "Vulkan";
    case WGPUBackendType_Metal:  return "Metal";
    default:                     return "Undefined";
    }
}

const char* formatString(WGPUTextureFormat f) {
    switch (f) {
    case WGPUTextureFormat_BGRA8Unorm:     return "BGRA8Unorm";
    case WGPUTextureFormat_RGBA8Unorm:     return "RGBA8Unorm";
    case WGPUTextureFormat_BGRA8UnormSrgb: return "BGRA8UnormSrgb";
    default:                               return "Other";
    }
}

std::string formatSuitesJson(const std::vector<ProbeOutcome>& outs, bool& allOk) {
    allOk = true;
    if (outs.empty()) return {};
    std::string s = "{\n      ";
    for (size_t i = 0; i < outs.size(); ++i) {
        const auto& o = outs[i];
        if (!o.ok) allOk = false;
        s.push_back('"');
        s.append(o.name);
        s.append("\": { \"ok\": ");
        s.append(o.ok ? "true" : "false");
        s.append(", \"detail\": \"");
        for (char c : o.detail) {
            if (c == '"') s.append("\\\"");
            else if (c == '\\') s.append("\\\\");
            else if (c == '\n') s.append("\\n");
            else s.push_back(c);
        }
        s.append("\"");
        if (!o.jsonBody.empty()) {
            s.append(", ");
            s.append(o.jsonBody);
        }
        s.append(" }");
        if (i + 1 < outs.size()) s.append(",\n      ");
    }
    s.append("\n    }");
    return s;
}

int writeProbeAndExit(AppState& app, int exitCode,
                      const std::vector<ProbeOutcome>* suites = nullptr) {
    ProbeReport r;
    r.gpuAvailable     = app.gpu.device != nullptr;
    r.queueAvailable   = app.gpu.queue  != nullptr;
    r.surfaceConfigured = app.surf.configured;
    r.framesSubmitted  = app.framesSubmitted;
    r.framesPresented  = app.framesPresented;
    r.adapterBackend   = backendString(app.gpu.adapterBackend);
    r.adapterVendor    = app.gpu.adapterVendor;
    r.adapterDevice    = app.gpu.adapterDevice;
    r.surfaceFormat    = formatString(app.surf.format);
    r.lastError        = app.lastRenderError.empty() ? app.gpu.lastError : app.lastRenderError;
    if (suites && !suites->empty()) {
        r.suitesJson = formatSuitesJson(*suites, r.suitesAllOk);
    }

    std::string err;
    if (!writeProbeReport(app.cfg.probeJsonPath, r, err)) {
        std::fprintf(stderr, "[webgpu_host] probe write failed: %s\n", err.c_str());
        return 2;
    }
    return exitCode;
}

} // namespace

int APIENTRY wWinMain(HINSTANCE hinst, HINSTANCE, PWSTR, int) {
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);

    AppState app;
    std::string parseErr;
    if (!parseCli(argc, argv, app.cfg, parseErr)) {
        MessageBoxA(nullptr, parseErr.c_str(), "webgpu_host", MB_OK | MB_ICONERROR);
        LocalFree(argv);
        return 64;
    }
    LocalFree(argv);

    // Console output for probe mode.
    if (app.cfg.mode == Config::Mode::Probe) {
        AttachConsole(ATTACH_PARENT_PROCESS);
        FILE* f;
        freopen_s(&f, "CONOUT$", "w", stdout);
        freopen_s(&f, "CONOUT$", "w", stderr);
    }

    app.hwnd = createWindow(hinst, app.cfg, app);
    if (!app.hwnd) {
        std::fprintf(stderr, "[webgpu_host] failed to create window\n");
        return 1;
    }
    app.surf.width  = app.cfg.width;
    app.surf.height = app.cfg.height;

    if (!createGpuBootstrap(app.cfg, app.gpu)) {
        std::fprintf(stderr, "[webgpu_host] bootstrap failed: %s\n", app.gpu.lastError.c_str());
        return app.cfg.mode == Config::Mode::Probe ? writeProbeAndExit(app, 3) : 3;
    }

    if (!attachSurface(app.gpu, app.hwnd, hinst,
                       app.surf.width, app.surf.height, app.surf)) {
        app.gpu.lastError = "attachSurface failed";
        return app.cfg.mode == Config::Mode::Probe ? writeProbeAndExit(app, 4) : 4;
    }
    configureSurface(app.gpu, app.surf);

    if (app.cfg.scene != Config::Scene::None) {
        app.scene = (app.cfg.scene == Config::Scene::Ball)
            ? createBouncingBallScene()
            : createTriangleScene();
        if (!app.scene->init(app.gpu.device, app.surf.format)) {
            app.gpu.lastError = std::string{"scene init failed: "} + app.scene->name();
            return app.cfg.mode == Config::Mode::Probe ? writeProbeAndExit(app, 5) : 5;
        }
        app.scene->resize(app.surf.width, app.surf.height);
    }

    // Probe suite: run once after bootstrap + surface configure, before the
    // scene loop. Surface roundtrip needs a configured surface.
    std::vector<ProbeOutcome> suiteResults;
    uint32_t suiteMask = 0;
    if (!app.cfg.suiteSpec.empty()) {
        std::string perr;
        suiteMask = parseProbeMask(app.cfg.suiteSpec, perr);
        if (!suiteMask) {
            std::fprintf(stderr, "[webgpu_host] --suite: %s\n", perr.c_str());
            return app.cfg.mode == Config::Mode::Probe
                ? writeProbeAndExit(app, 7) : 7;
        }
        suiteResults = runProbeSuite(app.gpu, &app.surf, suiteMask);
        for (const auto& r : suiteResults) {
            std::fprintf(stderr, "[probe] %-18s %-4s  %s\n",
                         r.name.c_str(), r.ok ? "ok" : "FAIL", r.detail.c_str());
        }
    }

    // Main loop: non-blocking pump + one render tick per iteration.
    auto tStart = std::chrono::steady_clock::now();
    auto tLast  = tStart;
    MSG msg{};
    bool running = true;
    while (running && !app.closing) {
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) { running = false; break; }
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        if (!running) break;

        // Pump Dawn. Required even for render-only workloads because device
        // lost / error callbacks come through here.
        if (app.gpu.instance) wgpuInstanceProcessEvents(app.gpu.instance);

        auto now = std::chrono::steady_clock::now();
        double dt = std::chrono::duration<double>(now - tLast).count();
        double  t = std::chrono::duration<double>(now - tStart).count();
        tLast = now;

        if (app.scene) {
            renderOneFrame(app, t, dt);
        } else if (app.cfg.mode == Config::Mode::Probe) {
            // No scene, probe-only. One tick is enough.
            break;
        }

        if (app.cfg.frameLimit && app.framesPresented >= app.cfg.frameLimit)
            break;
    }

    if (app.cfg.mode == Config::Mode::Probe) {
        const bool renderRequired = app.scene != nullptr;
        const bool renderOk       = !renderRequired || app.framesPresented > 0;
        bool suitesOk = true;
        for (const auto& r : suiteResults) suitesOk = suitesOk && r.ok;
        int code = (app.gpu.device && suitesOk && renderOk) ? 0 : 6;
        int wrote = writeProbeAndExit(app, code, &suiteResults);
        destroySurface(app.surf);
        destroyGpuBootstrap(app.gpu);
        return wrote;
    }

    destroySurface(app.surf);
    destroyGpuBootstrap(app.gpu);
    return 0;
}
