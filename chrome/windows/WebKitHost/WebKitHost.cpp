// WebKit-for-Windows embedding via the Apple Win port WKView C API.
// Consumed by the WinUI shell through cdecl P/Invoke (see Webkitium/FFI/WebKitHostBridge.cs).

#define WIN32_LEAN_AND_MEAN
#define WEBKITIUM_HOST_EXPORTS
#include "WebKitHost.h"

#include <WebKit/WKBase.h>
#include <WebKit/WKContext.h>
#include <WebKit/WKPage.h>
#include <WebKit/WKPageConfigurationRef.h>
#include <WebKit/WKString.h>
#include <WebKit/WKURL.h>
#include <WebKit/WKView.h>

#include <chrono>
#include <condition_variable>
#include <cstring>
#include <mutex>
#include <string>

namespace {

WKContextRef g_sharedContext = nullptr;
int g_viewCount = 0;
int g_initialized = 0;

struct WkHostView {
    WKViewRef view = nullptr;
    WKPageRef page = nullptr;
    HWND parentHwnd = nullptr;
};

std::string CopyWKString(WKStringRef string)
{
    if (!string)
        return {};
    size_t maxBytes = WKStringGetMaximumUTF8CStringSize(string);
    if (maxBytes == 0)
        return {};
    std::string out(maxBytes, '\0');
    size_t written = WKStringGetUTF8CString(string, out.data(), maxBytes);
    if (written > 0 && written <= out.size())
        out.resize(written - 1);
    else
        out.clear();
    return out;
}

std::string CopyWKURL(WKURLRef url)
{
    if (!url)
        return {};
    WKStringRef string = WKURLCopyURLString(url);
    std::string out = CopyWKString(string);
    if (string)
        WKRelease(string);
    return out;
}

struct ScriptWaitState {
    std::mutex mutex;
    std::condition_variable cv;
    bool done = false;
    std::string result;
};

void ScriptCallback(WKStringRef result, WKErrorRef /*error*/, void* context)
{
    auto* state = static_cast<ScriptWaitState*>(context);
    if (!state)
        return;
    std::lock_guard lock(state->mutex);
    state->result = CopyWKString(result);
    state->done = true;
    state->cv.notify_one();
}

size_t CopyToBuffer(const std::string& src, char* buf, size_t bufLen)
{
    if (bufLen == 0)
        return src.size() + 1;
    if (src.size() + 1 > bufLen)
        return src.size() + 1;
    memcpy(buf, src.c_str(), src.size() + 1);
    return src.size();
}

WkHostView* AsView(WkHostViewHandle handle)
{
    return reinterpret_cast<WkHostView*>(handle);
}

}  // namespace

extern "C" {

int wk_host_initialize(void)
{
    if (g_initialized)
        return 0;
    g_initialized = 1;
    return 0;
}

void wk_host_shutdown(void)
{
    if (g_sharedContext) {
        WKRelease(g_sharedContext);
        g_sharedContext = nullptr;
    }
    g_initialized = 0;
}

WkHostViewHandle wk_host_view_create(HWND parentHwnd, int x, int y, int width, int height)
{
    if (!parentHwnd || width <= 0 || height <= 0)
        return nullptr;

    if (!g_sharedContext) {
        g_sharedContext = WKContextCreate();
        if (!g_sharedContext)
            return nullptr;
    }

    auto* host = new WkHostView();
    host->parentHwnd = parentHwnd;

    WKPageConfigurationRef pageConfig = WKPageConfigurationCreate();
    WKPageConfigurationSetContext(pageConfig, g_sharedContext);

    RECT rect = { x, y, x + width, y + height };
    host->view = WKViewCreate(rect, g_sharedContext, pageConfig, parentHwnd);
    WKRelease(pageConfig);

    if (!host->view) {
        delete host;
        return nullptr;
    }

    host->page = WKViewGetPage(host->view);
    if (host->page)
        WKRetain(host->page);

    HWND child = WKViewGetWindow(host->view);
    if (child) {
        ShowWindow(child, SW_SHOW);
        SetWindowPos(child, nullptr, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    ++g_viewCount;
    return reinterpret_cast<WkHostViewHandle>(host);
}

void wk_host_view_destroy(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    if (!host)
        return;

    if (host->page) {
        WKRelease(host->page);
        host->page = nullptr;
    }
    if (host->view) {
        WKRelease(host->view);
        host->view = nullptr;
    }

    delete host;
    if (--g_viewCount <= 0 && g_viewCount == 0) {
        // Keep shared context alive for subsequent tabs in the same process.
    }
}

void wk_host_view_set_frame(WkHostViewHandle handle, int x, int y, int width, int height)
{
    auto* host = AsView(handle);
    if (!host || !host->view || width <= 0 || height <= 0)
        return;

    HWND child = WKViewGetWindow(host->view);
    if (child)
        SetWindowPos(child, nullptr, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
}

void wk_host_view_set_visible(WkHostViewHandle handle, int visible)
{
    auto* host = AsView(handle);
    if (!host || !host->view)
        return;
    HWND child = WKViewGetWindow(host->view);
    if (child)
        ShowWindow(child, visible ? SW_SHOW : SW_HIDE);
}

void wk_host_view_load_url(WkHostViewHandle handle, const char* utf8Url)
{
    auto* host = AsView(handle);
    if (!host || !host->page || !utf8Url || !*utf8Url)
        return;
    WKURLRef url = WKURLCreateWithUTF8CString(utf8Url);
    if (!url)
        return;
    WKPageLoadURL(host->page, url);
    WKRelease(url);
}

void wk_host_view_go_back(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    if (host && host->page)
        WKPageGoBack(host->page);
}

void wk_host_view_go_forward(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    if (host && host->page)
        WKPageGoForward(host->page);
}

void wk_host_view_reload(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    if (host && host->page)
        WKPageReload(host->page);
}

int wk_host_view_can_go_back(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    return (host && host->page && WKPageCanGoBack(host->page)) ? 1 : 0;
}

int wk_host_view_can_go_forward(WkHostViewHandle handle)
{
    auto* host = AsView(handle);
    return (host && host->page && WKPageCanGoForward(host->page)) ? 1 : 0;
}

size_t wk_host_view_copy_url(WkHostViewHandle handle, char* buf, size_t bufLen)
{
    auto* host = AsView(handle);
    if (!host || !host->page)
        return CopyToBuffer("", buf, bufLen);
    WKURLRef url = WKPageGetURL(host->page);
    std::string text = CopyWKURL(url);
    if (url)
        WKRelease(url);
    return CopyToBuffer(text, buf, bufLen);
}

size_t wk_host_view_copy_title(WkHostViewHandle handle, char* buf, size_t bufLen)
{
    auto* host = AsView(handle);
    if (!host || !host->page)
        return CopyToBuffer("", buf, bufLen);
    WKStringRef title = WKPageCopyTitle(host->page);
    std::string text = CopyWKString(title);
    if (title)
        WKRelease(title);
    return CopyToBuffer(text, buf, bufLen);
}

size_t wk_host_view_run_script(WkHostViewHandle handle, const char* utf8Script, char* out, size_t outLen, unsigned timeoutMs)
{
    auto* host = AsView(handle);
    if (!host || !host->page || !utf8Script)
        return 0;

    WKStringRef script = WKStringCreateWithUTF8CString(utf8Script);
    if (!script)
        return 0;

    ScriptWaitState state;
    WKPageRunJavaScriptInMainFrame(host->page, script, &state, ScriptCallback);
    WKRelease(script);

    std::unique_lock lock(state.mutex);
    if (!state.cv.wait_for(lock, std::chrono::milliseconds(timeoutMs), [&] { return state.done; }))
        return 0;

    return CopyToBuffer(state.result, out, outLen);
}

}  // extern "C"
