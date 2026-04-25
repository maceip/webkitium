#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define WK_TYPE_TAB_CONTENT (wk_tab_content_get_type ())
G_DECLARE_FINAL_TYPE (WkTabContent, wk_tab_content, WK, TAB_CONTENT, GtkBox)

WkTabContent *wk_tab_content_new   (void);
void          wk_tab_content_load_uri (WkTabContent *self,
                                       const char   *uri);

G_END_DECLS
