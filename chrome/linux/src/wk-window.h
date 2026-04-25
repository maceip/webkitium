#pragma once

#include <adwaita.h>
#include "wk-application.h"

G_BEGIN_DECLS

#define WK_TYPE_WINDOW (wk_window_get_type ())
G_DECLARE_FINAL_TYPE (WkWindow, wk_window, WK, WINDOW, AdwApplicationWindow)

WkWindow *wk_window_new (WkApplication *app);

G_END_DECLS
