#pragma once

#include <adwaita.h>

G_BEGIN_DECLS

#define WK_TYPE_TAB_CONTENT (wk_tab_content_get_type ())
G_DECLARE_FINAL_TYPE (WkTabContent, wk_tab_content, WK, TAB_CONTENT, GtkBox)

WkTabContent *wk_tab_content_new        (void);
void          wk_tab_content_load_uri   (WkTabContent *self, const char *uri);
void          wk_tab_content_go_back    (WkTabContent *self);
void          wk_tab_content_go_forward (WkTabContent *self);
void          wk_tab_content_reload     (WkTabContent *self);
void          wk_tab_content_stop       (WkTabContent *self);
const char   *wk_tab_content_get_title  (WkTabContent *self);
const char   *wk_tab_content_get_uri    (WkTabContent *self);
gboolean      wk_tab_content_can_go_back    (WkTabContent *self);
gboolean      wk_tab_content_can_go_forward (WkTabContent *self);
void          wk_tab_content_find       (WkTabContent *self, const char *query);
void          wk_tab_content_find_dismiss (WkTabContent *self);
void          wk_tab_content_set_zoom   (WkTabContent *self, double level);
double        wk_tab_content_get_zoom   (WkTabContent *self);
void          wk_tab_content_open_inspector (WkTabContent *self);
void          wk_tab_content_print      (WkTabContent *self);
void          wk_tab_content_load_error_page (WkTabContent *self,
                                              const char *failed_uri,
                                              const char *message);

G_END_DECLS
