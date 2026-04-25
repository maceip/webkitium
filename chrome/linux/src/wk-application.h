#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define WK_TYPE_APPLICATION (wk_application_get_type ())
G_DECLARE_FINAL_TYPE (WkApplication, wk_application, WK, APPLICATION, AdwApplication)

WkApplication *wk_application_new (void);

G_END_DECLS
