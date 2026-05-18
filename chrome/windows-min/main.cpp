// webkitium-min — Win32 + WebKit-for-Windows minimal browser test.
//
// Proves we can host a real WKView from our own WebKit-for-Windows build
// (Apple Win port, built via `perl Tools/Scripts/build-webkit --win`),
// load https://en.wikipedia.org, and capture a screenshot to PNG.
//
// No WebView2, no WinUI. Just a Win32 HWND with a WKView child window.
//
// Usage: webkitium_min.exe [--url https://...] [--out path.png] [--wait-seconds N]

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincodec.h>
#include <objbase.h>
#include <shellapi.h>
#include <wrl/client.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

// WebKit C API — Apple Win port. Headers at
// C:\W\webkit-src\Source\WebKit\UIProcess\API\C\ and
// C:\W\webkit-src\Source\WebKit\UIProcess\API\C\win\
#include <WebKit/WKBase.h>
#include <WebKit/WKContext.h>
#include <WebKit/WKPageConfigurationRef.h>
#include <WebKit/WKPageGroup.h>
#include <WebKit/WKPage.h>
#include <WebKit/WKString.h>
#include <WebKit/WKURL.h>
#include <WebKit/WKView.h>

#pragma comment(lib, "windowscodecs.lib")
#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")

namespace {

using Microsoft::WRL::ComPtr;

constexpr int kWinWidth = 1280;
constexpr int kWinHeight = 800;

HWND g_mainHwnd = nullptr;
WKViewRef g_view = nullptr;

struct CliArgs {
    std::string url = "https://en.wikipedia.org";
    std::wstring out = L"webkitium-min-wikipedia.png";
    int waitSeconds = 15;
};

std::wstring Utf8ToWide(const std::string& s) {
    if (s.empty()) return L"";
    int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0);
    std::wstring out(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.c_str(), (int)s.size(), out.data(), n);
    return out;
}

std::string WideToUtf8(const std::wstring& s) {
    if (s.empty()) return "";
    int n = WideCharToMultiByte(CP_UTF8, 0, s.c_str(), (int)s.size(), nullptr, 0, nullptr, nullptr);
    std::string out(n, '\0');
    WideCharToMultiByte(CP_UTF8, 0, s.c_str(), (int)s.size(), out.data(), n, nullptr, nullptr);
    return out;
}

CliArgs ParseCli() {
    CliArgs args;
    int argc = 0;
    LPWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    if (!argv) return args;
    for (int i = 1; i < argc; ++i) {
        std::wstring a = argv[i];
        if (a == L"--url" && i + 1 < argc) {
            args.url = WideToUtf8(argv[++i]);
        } else if (a == L"--out" && i + 1 < argc) {
            args.out = argv[++i];
        } else if (a == L"--wait-seconds" && i + 1 < argc) {
            args.waitSeconds = _wtoi(argv[++i]);
            if (args.waitSeconds <= 0) args.waitSeconds = 15;
        }
    }
    LocalFree(argv);
    return args;
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
    case WM_SIZE:
        if (g_view) {
            HWND child = WKViewGetWindow(g_view);
            if (child) {
                RECT rc; GetClientRect(hwnd, &rc);
                SetWindowPos(child, nullptr, 0, 0, rc.right - rc.left, rc.bottom - rc.top,
                             SWP_NOZORDER | SWP_NOACTIVATE);
            }
        }
        return 0;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

HWND CreateMainWindow(HINSTANCE inst) {
    WNDCLASSEXW wc = {};
    wc.cbSize = sizeof(wc);
    wc.style = CS_HREDRAW | CS_VREDRAW;
    wc.lpfnWndProc = WndProc;
    wc.hInstance = inst;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = L"WebkitiumMinMain";
    RegisterClassExW(&wc);

    RECT rc = {0, 0, kWinWidth, kWinHeight};
    AdjustWindowRectEx(&rc, WS_OVERLAPPEDWINDOW, FALSE, 0);
    return CreateWindowExW(0, L"WebkitiumMinMain", L"Webkitium (WebKit Win)",
                           WS_OVERLAPPEDWINDOW | WS_VISIBLE,
                           CW_USEDEFAULT, CW_USEDEFAULT,
                           rc.right - rc.left, rc.bottom - rc.top,
                           nullptr, nullptr, inst, nullptr);
}

bool CreateWebKitView(HWND parent, const std::string& url) {
    WKContextRef ctx = WKContextCreate();
    if (!ctx) {
        fwprintf(stderr, L"WKContextCreate failed\n");
        return false;
    }
    WKPageConfigurationRef pageConfig = WKPageConfigurationCreate();
    WKPageConfigurationSetContext(pageConfig, ctx);

    RECT rc; GetClientRect(parent, &rc);
    g_view = WKViewCreate(rc, ctx, pageConfig, parent);
    WKRelease(pageConfig);
    WKRelease(ctx);
    if (!g_view) {
        fwprintf(stderr, L"WKViewCreate failed\n");
        return false;
    }

    // Show the child HWND.
    HWND child = WKViewGetWindow(g_view);
    if (child) {
        ShowWindow(child, SW_SHOW);
        SetWindowPos(child, nullptr, 0, 0, rc.right - rc.left, rc.bottom - rc.top,
                     SWP_NOZORDER | SWP_NOACTIVATE);
    }

    WKPageRef page = WKViewGetPage(g_view);
    if (!page) {
        fwprintf(stderr, L"WKViewGetPage returned null\n");
        return false;
    }
    WKURLRef wkUrl = WKURLCreateWithUTF8CString(url.c_str());
    WKPageLoadURL(page, wkUrl);
    WKRelease(wkUrl);
    return true;
}

bool SaveHBITMAPasPNG(HBITMAP bmp, const std::wstring& path) {
    ComPtr<IWICImagingFactory> factory;
    HRESULT hr = CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER,
                                  IID_PPV_ARGS(&factory));
    if (FAILED(hr)) return false;

    ComPtr<IWICBitmap> wicBmp;
    hr = factory->CreateBitmapFromHBITMAP(bmp, nullptr, WICBitmapIgnoreAlpha, &wicBmp);
    if (FAILED(hr)) return false;

    ComPtr<IWICStream> stream;
    hr = factory->CreateStream(&stream);
    if (FAILED(hr)) return false;
    hr = stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE);
    if (FAILED(hr)) return false;

    ComPtr<IWICBitmapEncoder> encoder;
    hr = factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder);
    if (FAILED(hr)) return false;
    hr = encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache);
    if (FAILED(hr)) return false;

    ComPtr<IWICBitmapFrameEncode> frame;
    ComPtr<IPropertyBag2> props;
    hr = encoder->CreateNewFrame(&frame, &props);
    if (FAILED(hr)) return false;
    hr = frame->Initialize(props.Get());
    if (FAILED(hr)) return false;

    UINT w = 0, h = 0;
    wicBmp->GetSize(&w, &h);
    hr = frame->SetSize(w, h);
    if (FAILED(hr)) return false;

    WICPixelFormatGUID fmt = GUID_WICPixelFormat32bppBGRA;
    hr = frame->SetPixelFormat(&fmt);
    if (FAILED(hr)) return false;

    hr = frame->WriteSource(wicBmp.Get(), nullptr);
    if (FAILED(hr)) return false;

    hr = frame->Commit();
    if (FAILED(hr)) return false;
    hr = encoder->Commit();
    return SUCCEEDED(hr);
}

bool CaptureWindow(HWND hwnd, const std::wstring& outPath) {
    RECT rc; GetClientRect(hwnd, &rc);
    int w = rc.right - rc.left;
    int h = rc.bottom - rc.top;
    if (w <= 0 || h <= 0) return false;

    HDC screenDc = GetDC(nullptr);
    HDC memDc = CreateCompatibleDC(screenDc);
    HBITMAP bmp = CreateCompatibleBitmap(screenDc, w, h);
    HGDIOBJ old = SelectObject(memDc, bmp);

    // PW_RENDERFULLCONTENT (0x00000002) — required for WebKit's compositor surface.
    BOOL ok = PrintWindow(hwnd, memDc, 0x00000002);
    if (!ok) {
        // Fallback to BitBlt of the on-screen region.
        POINT pt = {0, 0};
        ClientToScreen(hwnd, &pt);
        BitBlt(memDc, 0, 0, w, h, screenDc, pt.x, pt.y, SRCCOPY);
    }
    SelectObject(memDc, old);

    bool saved = SaveHBITMAPasPNG(bmp, outPath);
    DeleteObject(bmp);
    DeleteDC(memDc);
    ReleaseDC(nullptr, screenDc);

    if (saved) wprintf(L"Saved %ls\n", outPath.c_str());
    else fwprintf(stderr, L"PNG save failed for %ls\n", outPath.c_str());
    return saved;
}

}  // namespace

int APIENTRY wWinMain(HINSTANCE inst, HINSTANCE, LPWSTR, int) {
    CliArgs args = ParseCli();
    HRESULT hr = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) return 2;

    g_mainHwnd = CreateMainWindow(inst);
    if (!g_mainHwnd) return 3;

    if (!CreateWebKitView(g_mainHwnd, args.url)) {
        DestroyWindow(g_mainHwnd);
        CoUninitialize();
        return 4;
    }

    ULONGLONG start = GetTickCount64();
    ULONGLONG deadline = start + (ULONGLONG)args.waitSeconds * 1000;

    MSG msg;
    bool captured = false;
    while (true) {
        while (PeekMessageW(&msg, nullptr, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT) goto done;
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        if (!captured && GetTickCount64() >= deadline) {
            CaptureWindow(g_mainHwnd, args.out);
            captured = true;
            PostQuitMessage(0);
        }
        Sleep(16);
    }
done:
    if (g_view) WKRelease(g_view);
    CoUninitialize();
    return captured ? 0 : 1;
}
