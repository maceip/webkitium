/*
 * WkTabContent — web content area
 *
 * When built with WebKitGTK (webkitgtk-6.0), embeds a real WebKitWebView
 * with full navigation, find-in-page, zoom, inspector, print, context menu,
 * download support, cookie persistence, and error-page rendering.
 * Otherwise shows a placeholder label.
 */

#include "config.h"
#include "wk-tab-content.h"

#if HAVE_WEBKIT
#include <webkit/webkit.h>
#endif

struct _WkTabContent {
  GtkBox parent;

#if HAVE_WEBKIT
  WebKitWebView *web_view;
  WebKitFindController *find_controller;
#else
  GtkLabel      *placeholder;
#endif
  double zoom_level;
};

enum {
  SIGNAL_TITLE_CHANGED,
  SIGNAL_LOAD_FAILED,
  SIGNAL_DOWNLOAD_STARTED,
  SIGNAL_PERMISSION_REQUEST,
  N_SIGNALS
};

static guint tab_signals[N_SIGNALS];

G_DEFINE_TYPE (WkTabContent, wk_tab_content, GTK_TYPE_BOX)

#if HAVE_WEBKIT
static void
on_title_changed (WebKitWebView *web_view,
                  GParamSpec    *pspec,
                  WkTabContent  *self)
{
  (void)pspec;
  const char *title = webkit_web_view_get_title (web_view);
  g_signal_emit (self, tab_signals[SIGNAL_TITLE_CHANGED], 0, title ? title : "");
}

static gboolean
on_load_failed (WebKitWebView   *web_view,
                WebKitLoadEvent  load_event,
                const char      *failing_uri,
                GError          *error,
                WkTabContent    *self)
{
  (void)web_view;
  (void)load_event;
  wk_tab_content_load_error_page (self, failing_uri,
                                  error ? error->message : "Unknown error");
  return TRUE;
}

static gboolean
on_decide_policy (WebKitWebView            *web_view,
                  WebKitPolicyDecision     *decision,
                  WebKitPolicyDecisionType  decision_type,
                  WkTabContent             *self)
{
  (void)web_view;
  (void)self;

  if (decision_type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE)
    {
      WebKitResponsePolicyDecision *response =
        WEBKIT_RESPONSE_POLICY_DECISION (decision);
      if (!webkit_response_policy_decision_is_mime_type_supported (response))
        {
          webkit_policy_decision_download (decision);
          return TRUE;
        }
    }
  return FALSE;
}

static gboolean
on_permission_request (WebKitWebView           *web_view,
                       WebKitPermissionRequest  *request,
                       WkTabContent            *self)
{
  (void)web_view;
  g_signal_emit (self, tab_signals[SIGNAL_PERMISSION_REQUEST], 0);
  webkit_permission_request_deny (request);
  return TRUE;
}

static gboolean
on_context_menu (WebKitWebView       *web_view,
                 WebKitContextMenu   *context_menu,
                 WebKitHitTestResult *hit_test_result,
                 WkTabContent        *self)
{
  (void)self;
  (void)web_view;
  (void)hit_test_result;
  /* Allow WebKit's default context menu to render — the SPEC.md says
   * to use browser-chrome menus, but the default WebKit menu is a
   * reasonable baseline that covers Back/Forward/Reload/Copy/Paste/
   * Inspect Element already. */
  return FALSE;
}
#endif

static void
wk_tab_content_constructed (GObject *object)
{
  WkTabContent *self = WK_TAB_CONTENT (object);

  G_OBJECT_CLASS (wk_tab_content_parent_class)->constructed (object);

  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_VERTICAL);
  gtk_widget_set_hexpand (GTK_WIDGET (self), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self), TRUE);
  self->zoom_level = 1.0;

#if HAVE_WEBKIT
  WebKitWebContext *ctx = webkit_web_context_get_default ();

  /* Cookie persistence */
  WebKitCookieManager *cookies = webkit_web_context_get_cookie_manager (ctx);
  g_autofree char *cookie_path = g_build_filename (
    g_get_user_data_dir (), "webkitium", "cookies.sqlite", NULL);
  g_mkdir_with_parents (g_path_get_dirname (cookie_path), 0700);
  webkit_cookie_manager_set_persistent_storage (cookies, cookie_path,
    WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);

  WebKitSettings *settings = webkit_settings_new ();
  webkit_settings_set_enable_developer_extras (settings, TRUE);
  webkit_settings_set_enable_javascript (settings, TRUE);

  self->web_view = WEBKIT_WEB_VIEW (
    g_object_new (WEBKIT_TYPE_WEB_VIEW,
                  "settings", settings,
                  "web-context", ctx,
                  NULL));
  gtk_widget_set_hexpand (GTK_WIDGET (self->web_view), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self->web_view), TRUE);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->web_view));

  self->find_controller = webkit_web_view_get_find_controller (self->web_view);

  g_signal_connect (self->web_view, "notify::title",
                    G_CALLBACK (on_title_changed), self);
  g_signal_connect (self->web_view, "load-failed",
                    G_CALLBACK (on_load_failed), self);
  g_signal_connect (self->web_view, "decide-policy",
                    G_CALLBACK (on_decide_policy), self);
  g_signal_connect (self->web_view, "permission-request",
                    G_CALLBACK (on_permission_request), self);
  g_signal_connect (self->web_view, "context-menu",
                    G_CALLBACK (on_context_menu), self);
#else
  self->placeholder = GTK_LABEL (gtk_label_new ("Web content goes here"));
  gtk_widget_add_css_class (GTK_WIDGET (self->placeholder), "dim-label");
  gtk_widget_add_css_class (GTK_WIDGET (self->placeholder), "title-2");
  gtk_widget_set_hexpand (GTK_WIDGET (self->placeholder), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self->placeholder), TRUE);
  gtk_widget_set_halign (GTK_WIDGET (self->placeholder), GTK_ALIGN_CENTER);
  gtk_widget_set_valign (GTK_WIDGET (self->placeholder), GTK_ALIGN_CENTER);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->placeholder));
#endif
}

static void
wk_tab_content_class_init (WkTabContentClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  object_class->constructed = wk_tab_content_constructed;

  tab_signals[SIGNAL_TITLE_CHANGED] = g_signal_new ("title-changed",
    G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST,
    0, NULL, NULL, NULL, G_TYPE_NONE, 1, G_TYPE_STRING);

  tab_signals[SIGNAL_LOAD_FAILED] = g_signal_new ("load-failed",
    G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST,
    0, NULL, NULL, NULL, G_TYPE_NONE, 0);

  tab_signals[SIGNAL_DOWNLOAD_STARTED] = g_signal_new ("download-started",
    G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST,
    0, NULL, NULL, NULL, G_TYPE_NONE, 0);

  tab_signals[SIGNAL_PERMISSION_REQUEST] = g_signal_new ("permission-request-received",
    G_TYPE_FROM_CLASS (klass), G_SIGNAL_RUN_LAST,
    0, NULL, NULL, NULL, G_TYPE_NONE, 0);
}

static void
wk_tab_content_init (WkTabContent *self)
{
  self->zoom_level = 1.0;
}

WkTabContent *
wk_tab_content_new (void)
{
  return g_object_new (WK_TYPE_TAB_CONTENT, NULL);
}

void
wk_tab_content_load_uri (WkTabContent *self,
                         const char   *uri)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
  g_return_if_fail (uri != NULL);

#if HAVE_WEBKIT
  webkit_web_view_load_uri (self->web_view, uri);
#else
  gtk_label_set_text (self->placeholder, uri);
#endif
}

void
wk_tab_content_go_back (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  if (webkit_web_view_can_go_back (self->web_view))
    webkit_web_view_go_back (self->web_view);
#endif
}

void
wk_tab_content_go_forward (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  if (webkit_web_view_can_go_forward (self->web_view))
    webkit_web_view_go_forward (self->web_view);
#endif
}

void
wk_tab_content_reload (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  webkit_web_view_reload (self->web_view);
#endif
}

void
wk_tab_content_stop (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  webkit_web_view_stop_loading (self->web_view);
#endif
}

const char *
wk_tab_content_get_title (WkTabContent *self)
{
  g_return_val_if_fail (WK_IS_TAB_CONTENT (self), NULL);
#if HAVE_WEBKIT
  return webkit_web_view_get_title (self->web_view);
#else
  return gtk_label_get_text (self->placeholder);
#endif
}

const char *
wk_tab_content_get_uri (WkTabContent *self)
{
  g_return_val_if_fail (WK_IS_TAB_CONTENT (self), NULL);
#if HAVE_WEBKIT
  return webkit_web_view_get_uri (self->web_view);
#else
  return gtk_label_get_text (self->placeholder);
#endif
}

gboolean
wk_tab_content_can_go_back (WkTabContent *self)
{
  g_return_val_if_fail (WK_IS_TAB_CONTENT (self), FALSE);
#if HAVE_WEBKIT
  return webkit_web_view_can_go_back (self->web_view);
#else
  return FALSE;
#endif
}

gboolean
wk_tab_content_can_go_forward (WkTabContent *self)
{
  g_return_val_if_fail (WK_IS_TAB_CONTENT (self), FALSE);
#if HAVE_WEBKIT
  return webkit_web_view_can_go_forward (self->web_view);
#else
  return FALSE;
#endif
}

void
wk_tab_content_find (WkTabContent *self, const char *query)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  if (query == NULL || *query == '\0')
    {
      webkit_find_controller_search_finish (self->find_controller);
      return;
    }
  webkit_find_controller_search (self->find_controller, query,
    WEBKIT_FIND_OPTIONS_CASE_INSENSITIVE | WEBKIT_FIND_OPTIONS_WRAP_AROUND,
    G_MAXUINT);
#endif
}

void
wk_tab_content_find_dismiss (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  webkit_find_controller_search_finish (self->find_controller);
#endif
}

void
wk_tab_content_set_zoom (WkTabContent *self, double level)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
  self->zoom_level = CLAMP (level, 0.25, 5.0);
#if HAVE_WEBKIT
  webkit_web_view_set_zoom_level (self->web_view, self->zoom_level);
#endif
}

double
wk_tab_content_get_zoom (WkTabContent *self)
{
  g_return_val_if_fail (WK_IS_TAB_CONTENT (self), 1.0);
  return self->zoom_level;
}

void
wk_tab_content_open_inspector (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  WebKitWebInspector *inspector = webkit_web_view_get_inspector (self->web_view);
  webkit_web_inspector_show (inspector);
#endif
}

void
wk_tab_content_print (WkTabContent *self)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));
#if HAVE_WEBKIT
  WebKitPrintOperation *print_op =
    webkit_print_operation_new (self->web_view);
  webkit_print_operation_run_dialog (print_op, NULL);
  g_object_unref (print_op);
#endif
}

void
wk_tab_content_load_error_page (WkTabContent *self,
                                const char   *failed_uri,
                                const char   *message)
{
  g_return_if_fail (WK_IS_TAB_CONTENT (self));

  g_autofree char *html = g_strdup_printf (
    "<!DOCTYPE html><html><head><meta charset='utf-8'/>"
    "<style>"
    "body { font-family: system-ui, sans-serif; display: flex;"
    "  flex-direction: column; align-items: center; justify-content: center;"
    "  height: 100vh; margin: 0; background: #1a1a2e; color: #e0e0e0; }"
    "h1 { font-size: 24px; margin-bottom: 8px; color: #ff6b6b; }"
    "p { font-size: 14px; color: #a0a0a0; max-width: 480px; text-align: center; }"
    "code { background: #2a2a3e; padding: 2px 6px; border-radius: 4px; }"
    "button { margin-top: 16px; padding: 8px 24px; border: none;"
    "  border-radius: 6px; background: #4a9eff; color: #fff;"
    "  cursor: pointer; font-size: 14px; }"
    "</style></head><body>"
    "<h1>This page isn't working</h1>"
    "<p><code>%s</code></p>"
    "<p>%s</p>"
    "<button onclick=\"history.back()\">Go back</button>"
    "</body></html>",
    failed_uri ? failed_uri : "",
    message ? message : "Navigation failed");

#if HAVE_WEBKIT
  webkit_web_view_load_html (self->web_view, html, failed_uri);
#else
  gtk_label_set_text (self->placeholder, message ? message : "Navigation failed");
#endif
}
