/*
 * WkWindow — main browser window
 *
 * Layout mirrors the macOS NavigationSplitView / Windows NavigationView:
 *
 *   AdwNavigationSplitView
 *     sidebar:  WkSidebar (search + tab list + footer)
 *     content:  AdwToolbarView
 *                 top: AdwHeaderBar with WkOmnibar + nav buttons
 *                 content: WkTabContent (WebKitWebView or placeholder)
 */

#include "wk-window.h"
#include "wk-sidebar.h"
#include "wk-omnibar.h"
#include "wk-tab-content.h"

struct _WkWindow {
  AdwApplicationWindow parent;

  AdwNavigationSplitView *split_view;
  WkSidebar              *sidebar;
  WkOmnibar              *omnibar;
  WkTabContent           *tab_content;
};

G_DEFINE_TYPE (WkWindow, wk_window, ADW_TYPE_APPLICATION_WINDOW)

static void
on_omnibar_navigate (WkOmnibar  *omnibar,
                     const char *uri,
                     WkWindow   *self)
{
  wk_tab_content_load_uri (self->tab_content, uri);
}

static GtkWidget *
build_content_page (WkWindow *self)
{
  /* Toolbar view: header bar on top, web content below */
  AdwToolbarView *toolbar_view = ADW_TOOLBAR_VIEW (adw_toolbar_view_new ());

  /* Header bar with nav buttons + omnibar */
  AdwHeaderBar *header = ADW_HEADER_BAR (adw_header_bar_new ());
  adw_header_bar_set_show_title (header, FALSE);

  /* Back / Forward / Reload */
  GtkButton *back_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("go-previous-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (back_btn), "Back");
  adw_header_bar_pack_start (header, GTK_WIDGET (back_btn));

  GtkButton *fwd_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("go-next-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (fwd_btn), "Forward");
  adw_header_bar_pack_start (header, GTK_WIDGET (fwd_btn));

  GtkButton *reload_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("view-refresh-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (reload_btn), "Reload (Ctrl+R)");
  adw_header_bar_pack_start (header, GTK_WIDGET (reload_btn));

  /* Omnibar — center of header */
  self->omnibar = wk_omnibar_new ();
  gtk_widget_set_hexpand (GTK_WIDGET (self->omnibar), TRUE);
  adw_header_bar_set_title_widget (header, GTK_WIDGET (self->omnibar));
  g_signal_connect (self->omnibar, "navigate",
                    G_CALLBACK (on_omnibar_navigate), self);

  /* Extensions + More on trailing side */
  GtkButton *ext_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("application-x-addon-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (ext_btn), "Extensions");
  adw_header_bar_pack_end (header, GTK_WIDGET (ext_btn));

  GtkButton *more_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("view-more-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (more_btn), "More");
  adw_header_bar_pack_end (header, GTK_WIDGET (more_btn));

  adw_toolbar_view_add_top_bar (toolbar_view, GTK_WIDGET (header));

  /* Web content area */
  self->tab_content = wk_tab_content_new ();
  adw_toolbar_view_set_content (toolbar_view, GTK_WIDGET (self->tab_content));

  return GTK_WIDGET (toolbar_view);
}

static void
wk_window_constructed (GObject *object)
{
  WkWindow *self = WK_WINDOW (object);

  G_OBJECT_CLASS (wk_window_parent_class)->constructed (object);

  gtk_window_set_title (GTK_WINDOW (self), "Webkitium");
  gtk_window_set_default_size (GTK_WINDOW (self), 1280, 800);

  /* NavigationSplitView: sidebar | content */
  self->split_view = ADW_NAVIGATION_SPLIT_VIEW (adw_navigation_split_view_new ());
  adw_navigation_split_view_set_min_sidebar_width (self->split_view, 200);
  adw_navigation_split_view_set_max_sidebar_width (self->split_view, 320);

  /* Sidebar */
  self->sidebar = wk_sidebar_new ();
  AdwNavigationPage *sidebar_page = adw_navigation_page_new (
    GTK_WIDGET (self->sidebar), "Sidebar");
  adw_navigation_split_view_set_sidebar (self->split_view, sidebar_page);

  /* Content */
  GtkWidget *content = build_content_page (self);
  AdwNavigationPage *content_page = adw_navigation_page_new (content, "Content");
  adw_navigation_split_view_set_content (self->split_view, content_page);

  adw_application_window_set_content (ADW_APPLICATION_WINDOW (self),
                                      GTK_WIDGET (self->split_view));

  /* Ctrl+\ toggles sidebar */
  GtkShortcutController *sc = GTK_SHORTCUT_CONTROLLER (
    gtk_shortcut_controller_new ());
  gtk_shortcut_controller_set_scope (sc, GTK_SHORTCUT_SCOPE_MANAGED);
  gtk_widget_add_controller (GTK_WIDGET (self), GTK_EVENT_CONTROLLER (sc));
}

static void
wk_window_class_init (WkWindowClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  object_class->constructed = wk_window_constructed;
}

static void
wk_window_init (WkWindow *self)
{
}

WkWindow *
wk_window_new (WkApplication *app)
{
  return g_object_new (WK_TYPE_WINDOW,
                       "application", app,
                       NULL);
}
