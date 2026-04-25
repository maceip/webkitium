/*
 * WkTabContent — web content area
 *
 * When built with WebKitGTK (webkitgtk-6.0), embeds a real WebKitWebView.
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
#else
  GtkLabel      *placeholder;
#endif
};

G_DEFINE_TYPE (WkTabContent, wk_tab_content, GTK_TYPE_BOX)

static void
wk_tab_content_constructed (GObject *object)
{
  WkTabContent *self = WK_TAB_CONTENT (object);

  G_OBJECT_CLASS (wk_tab_content_parent_class)->constructed (object);

  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_VERTICAL);
  gtk_widget_set_hexpand (GTK_WIDGET (self), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self), TRUE);

#if HAVE_WEBKIT
  self->web_view = WEBKIT_WEB_VIEW (webkit_web_view_new ());
  gtk_widget_set_hexpand (GTK_WIDGET (self->web_view), TRUE);
  gtk_widget_set_vexpand (GTK_WIDGET (self->web_view), TRUE);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->web_view));
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
}

static void
wk_tab_content_init (WkTabContent *self)
{
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
