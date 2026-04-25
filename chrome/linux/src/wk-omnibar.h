#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define WK_TYPE_OMNIBAR (wk_omnibar_get_type ())
G_DECLARE_FINAL_TYPE (WkOmnibar, wk_omnibar, WK, OMNIBAR, GtkBox)

WkOmnibar *wk_omnibar_new (void);

G_END_DECLS
