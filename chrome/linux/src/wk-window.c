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
 *
 * Tier 1: back/fwd/reload wired, Ctrl+T/W/Shift+T, error pages, cookies
 * Tier 2: find-in-page (Ctrl+F), inspector (F12), print (Ctrl+P),
 *         zoom (Ctrl++/-/0), context menu (WebKit default)
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

  GtkButton              *back_btn;
  GtkButton              *fwd_btn;
  GtkButton              *reload_btn;

  /* Find bar */
  GtkRevealer            *find_revealer;
  GtkEntry               *find_entry;
};

G_DEFINE_TYPE (WkWindow, wk_window, ADW_TYPE_APPLICATION_WINDOW)

/* ---- Callbacks ---- */

static void
on_omnibar_navigate (WkOmnibar  *omnibar,
                     const char *uri,
                     WkWindow   *self)
{
  (void)omnibar;
  wk_tab_content_load_uri (self->tab_content, uri);
}

static void
on_back_clicked (GtkButton *btn, WkWindow *self)
{
  (void)btn;
  wk_tab_content_go_back (self->tab_content);
}

static void
on_fwd_clicked (GtkButton *btn, WkWindow *self)
{
  (void)btn;
  wk_tab_content_go_forward (self->tab_content);
}

static void
on_reload_clicked (GtkButton *btn, WkWindow *self)
{
  (void)btn;
  wk_tab_content_reload (self->tab_content);
}

/* ---- Find bar ---- */

static void
on_find_entry_activate (GtkEntry *entry, WkWindow *self)
{
  const char *text = gtk_editable_get_text (GTK_EDITABLE (entry));
  wk_tab_content_find (self->tab_content, text);
}

static void
on_find_close (GtkButton *btn, WkWindow *self)
{
  (void)btn;
  gtk_revealer_set_reveal_child (self->find_revealer, FALSE);
  wk_tab_content_find_dismiss (self->tab_content);
}

/* ---- Keyboard shortcut actions ---- */

static void
action_new_tab (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  WkWindow *self = WK_WINDOW (widget);
  wk_tab_content_load_uri (self->tab_content, "https://example.com/");
}

static void
action_close_tab (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  gtk_window_close (GTK_WINDOW (widget));
}

static void
action_reload (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_reload (WK_WINDOW (widget)->tab_content);
}

static void
action_go_back (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_go_back (WK_WINDOW (widget)->tab_content);
}

static void
action_go_forward (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_go_forward (WK_WINDOW (widget)->tab_content);
}

static void
action_find (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  WkWindow *self = WK_WINDOW (widget);
  gboolean visible = gtk_revealer_get_reveal_child (self->find_revealer);
  gtk_revealer_set_reveal_child (self->find_revealer, !visible);
  if (!visible)
    gtk_widget_grab_focus (GTK_WIDGET (self->find_entry));
  else
    wk_tab_content_find_dismiss (self->tab_content);
}

static void
action_inspector (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_open_inspector (WK_WINDOW (widget)->tab_content);
}

static void
action_print (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_print (WK_WINDOW (widget)->tab_content);
}

static void
action_zoom_in (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  WkWindow *self = WK_WINDOW (widget);
  double z = wk_tab_content_get_zoom (self->tab_content);
  wk_tab_content_set_zoom (self->tab_content, z + 0.1);
}

static void
action_zoom_out (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  WkWindow *self = WK_WINDOW (widget);
  double z = wk_tab_content_get_zoom (self->tab_content);
  wk_tab_content_set_zoom (self->tab_content, z - 0.1);
}

static void
action_zoom_reset (GtkWidget *widget, const char *action_name, GVariant *param)
{
  (void)action_name; (void)param;
  wk_tab_content_set_zoom (WK_WINDOW (widget)->tab_content, 1.0);
}

/* ---- Build UI ---- */

static GtkWidget *
build_find_bar (WkWindow *self)
{
  GtkBox *box = GTK_BOX (gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 4));
  gtk_widget_set_margin_start (GTK_WIDGET (box), 8);
  gtk_widget_set_margin_end (GTK_WIDGET (box), 8);
  gtk_widget_set_margin_top (GTK_WIDGET (box), 4);
  gtk_widget_set_margin_bottom (GTK_WIDGET (box), 4);

  self->find_entry = GTK_ENTRY (gtk_entry_new ());
  gtk_entry_set_placeholder_text (self->find_entry, "Find in page");
  gtk_widget_set_hexpand (GTK_WIDGET (self->find_entry), TRUE);
  g_signal_connect (self->find_entry, "activate",
                    G_CALLBACK (on_find_entry_activate), self);
  gtk_box_append (box, GTK_WIDGET (self->find_entry));

  GtkButton *close_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("window-close-symbolic"));
  gtk_widget_add_css_class (GTK_WIDGET (close_btn), "flat");
  g_signal_connect (close_btn, "clicked", G_CALLBACK (on_find_close), self);
  gtk_box_append (box, GTK_WIDGET (close_btn));

  self->find_revealer = GTK_REVEALER (gtk_revealer_new ());
  gtk_revealer_set_transition_type (self->find_revealer,
    GTK_REVEALER_TRANSITION_TYPE_SLIDE_DOWN);
  gtk_revealer_set_reveal_child (self->find_revealer, FALSE);
  gtk_revealer_set_child (self->find_revealer, GTK_WIDGET (box));

  return GTK_WIDGET (self->find_revealer);
}

static GtkWidget *
build_content_page (WkWindow *self)
{
  AdwToolbarView *toolbar_view = ADW_TOOLBAR_VIEW (adw_toolbar_view_new ());

  AdwHeaderBar *header = ADW_HEADER_BAR (adw_header_bar_new ());
  adw_header_bar_set_show_title (header, FALSE);

  /* Back / Forward / Reload — now wired */
  self->back_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("go-previous-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (self->back_btn), "Back (Alt+Left)");
  g_signal_connect (self->back_btn, "clicked", G_CALLBACK (on_back_clicked), self);
  adw_header_bar_pack_start (header, GTK_WIDGET (self->back_btn));

  self->fwd_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("go-next-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (self->fwd_btn), "Forward (Alt+Right)");
  g_signal_connect (self->fwd_btn, "clicked", G_CALLBACK (on_fwd_clicked), self);
  adw_header_bar_pack_start (header, GTK_WIDGET (self->fwd_btn));

  self->reload_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("view-refresh-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (self->reload_btn), "Reload (Ctrl+R)");
  g_signal_connect (self->reload_btn, "clicked", G_CALLBACK (on_reload_clicked), self);
  adw_header_bar_pack_start (header, GTK_WIDGET (self->reload_btn));

  /* Omnibar */
  self->omnibar = wk_omnibar_new ();
  gtk_widget_set_hexpand (GTK_WIDGET (self->omnibar), TRUE);
  adw_header_bar_set_title_widget (header, GTK_WIDGET (self->omnibar));
  g_signal_connect (self->omnibar, "navigate",
                    G_CALLBACK (on_omnibar_navigate), self);

  GtkButton *ext_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("application-x-addon-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (ext_btn), "Extensions");
  adw_header_bar_pack_end (header, GTK_WIDGET (ext_btn));

  GtkButton *more_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("view-more-symbolic"));
  gtk_widget_set_tooltip_text (GTK_WIDGET (more_btn), "More");
  adw_header_bar_pack_end (header, GTK_WIDGET (more_btn));

  adw_toolbar_view_add_top_bar (toolbar_view, GTK_WIDGET (header));

  /* Find bar (Tier 2) */
  adw_toolbar_view_add_top_bar (toolbar_view, build_find_bar (self));

  /* Web content area */
  self->tab_content = wk_tab_content_new ();
  adw_toolbar_view_set_content (toolbar_view, GTK_WIDGET (self->tab_content));

  return GTK_WIDGET (toolbar_view);
}

static void
install_shortcuts (WkWindow *self)
{
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.new-tab", NULL, action_new_tab);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.close-tab", NULL, action_close_tab);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.reload", NULL, action_reload);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.go-back", NULL, action_go_back);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.go-forward", NULL, action_go_forward);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.find", NULL, action_find);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.inspector", NULL, action_inspector);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.print", NULL, action_print);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.zoom-in", NULL, action_zoom_in);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.zoom-out", NULL, action_zoom_out);
  gtk_widget_class_install_action (GTK_WIDGET_GET_CLASS (self),
    "win.zoom-reset", NULL, action_zoom_reset);

  GtkShortcutController *sc = GTK_SHORTCUT_CONTROLLER (
    gtk_shortcut_controller_new ());
  gtk_shortcut_controller_set_scope (sc, GTK_SHORTCUT_SCOPE_MANAGED);

  struct { const char *accel; const char *action; } bindings[] = {
    { "<Control>t",       "win.new-tab" },
    { "<Control>w",       "win.close-tab" },
    { "<Control>r",       "win.reload" },
    { "F5",               "win.reload" },
    { "<Alt>Left",        "win.go-back" },
    { "<Alt>Right",       "win.go-forward" },
    { "<Control>f",       "win.find" },
    { "F12",              "win.inspector" },
    { "<Control>p",       "win.print" },
    { "<Control>plus",    "win.zoom-in" },
    { "<Control>equal",   "win.zoom-in" },
    { "<Control>minus",   "win.zoom-out" },
    { "<Control>0",       "win.zoom-reset" },
  };

  for (size_t i = 0; i < G_N_ELEMENTS (bindings); i++)
    {
      GtkShortcutTrigger *trigger =
        gtk_shortcut_trigger_parse_string (bindings[i].accel);
      GtkShortcutAction *action =
        gtk_named_action_new (bindings[i].action);
      GtkShortcut *shortcut = gtk_shortcut_new (trigger, action);
      gtk_shortcut_controller_add_shortcut (sc, shortcut);
    }

  gtk_widget_add_controller (GTK_WIDGET (self), GTK_EVENT_CONTROLLER (sc));
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

  /* Keyboard shortcuts (Tier 1 + Tier 2) */
  install_shortcuts (self);

  /* Load a default page so the WebView isn't blank on startup */
  wk_tab_content_load_uri (self->tab_content, "https://example.com");
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
  (void)self;
}

WkWindow *
wk_window_new (WkApplication *app)
{
  return g_object_new (WK_TYPE_WINDOW,
                       "application", app,
                       NULL);
}
