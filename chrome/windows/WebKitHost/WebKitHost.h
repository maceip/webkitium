#pragma once

#include <windows.h>

#ifdef WEBKITIUM_HOST_EXPORTS
#define WK_HOST_API __declspec(dllexport)
#else
#define WK_HOST_API __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkHostView* WkHostViewHandle;

WK_HOST_API int wk_host_initialize(void);
WK_HOST_API void wk_host_shutdown(void);

WK_HOST_API WkHostViewHandle wk_host_view_create(HWND parentHwnd, int x, int y, int width, int height);
WK_HOST_API void wk_host_view_destroy(WkHostViewHandle view);
WK_HOST_API void wk_host_view_set_frame(WkHostViewHandle view, int x, int y, int width, int height);
WK_HOST_API void wk_host_view_set_visible(WkHostViewHandle view, int visible);

WK_HOST_API void wk_host_view_load_url(WkHostViewHandle view, const char* utf8Url);
WK_HOST_API void wk_host_view_go_back(WkHostViewHandle view);
WK_HOST_API void wk_host_view_go_forward(WkHostViewHandle view);
WK_HOST_API void wk_host_view_reload(WkHostViewHandle view);
WK_HOST_API int wk_host_view_can_go_back(WkHostViewHandle view);
WK_HOST_API int wk_host_view_can_go_forward(WkHostViewHandle view);

/** Copies UTF-8 URL into buf; returns bytes written (excluding NUL) or required size if buf too small. */
WK_HOST_API size_t wk_host_view_copy_url(WkHostViewHandle view, char* buf, size_t bufLen);
WK_HOST_API size_t wk_host_view_copy_title(WkHostViewHandle view, char* buf, size_t bufLen);

/**
 * Runs script in the main frame; blocks up to timeoutMs waiting for the result string.
 * Returns bytes written into out (UTF-8) or 0 on failure/timeout.
 */
WK_HOST_API size_t wk_host_view_run_script(WkHostViewHandle view, const char* utf8Script, char* out, size_t outLen, unsigned timeoutMs);

#ifdef __cplusplus
}
#endif
