#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define WK_TYPE_SIDEBAR (wk_sidebar_get_type ())
G_DECLARE_FINAL_TYPE (WkSidebar, wk_sidebar, WK, SIDEBAR, GtkBox)

WkSidebar *wk_sidebar_new (void);

G_END_DECLS
