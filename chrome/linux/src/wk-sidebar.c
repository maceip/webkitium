/*
 * WkSidebar — left panel matching macOS/Windows sidepanel
 *
 * Layout:
 *   workspace search field
 *   sectioned tab list (WORKSPACE, SPACES)
 *   spacer
 *   footer (settings + avatar)
 */

#include "wk-sidebar.h"

struct _WkSidebar {
  GtkBox parent;

  GtkSearchEntry *search;
  GtkListBox     *tab_list;
};

G_DEFINE_TYPE (WkSidebar, wk_sidebar, GTK_TYPE_BOX)

static GtkWidget *
make_section_header (const char *text)
{
  GtkLabel *label = GTK_LABEL (gtk_label_new (text));
  gtk_label_set_xalign (label, 0.0);
  gtk_widget_add_css_class (GTK_WIDGET (label), "caption-heading");
  gtk_widget_add_css_class (GTK_WIDGET (label), "dim-label");
  gtk_widget_set_margin_start (GTK_WIDGET (label), 12);
  gtk_widget_set_margin_top (GTK_WIDGET (label), 12);
  gtk_widget_set_margin_bottom (GTK_WIDGET (label), 4);
  return GTK_WIDGET (label);
}

static GtkWidget *
make_sidebar_row (const char *icon_name, const char *label_text)
{
  GtkBox *row = GTK_BOX (gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 8));
  gtk_widget_set_margin_start (GTK_WIDGET (row), 8);
  gtk_widget_set_margin_end (GTK_WIDGET (row), 8);
  gtk_widget_set_margin_top (GTK_WIDGET (row), 2);
  gtk_widget_set_margin_bottom (GTK_WIDGET (row), 2);

  GtkImage *icon = GTK_IMAGE (gtk_image_new_from_icon_name (icon_name));
  gtk_image_set_pixel_size (icon, 16);
  gtk_box_append (row, GTK_WIDGET (icon));

  GtkLabel *label = GTK_LABEL (gtk_label_new (label_text));
  gtk_label_set_xalign (label, 0.0);
  gtk_box_append (row, GTK_WIDGET (label));

  return GTK_WIDGET (row);
}

static GtkWidget *
build_footer (void)
{
  GtkBox *footer = GTK_BOX (gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 8));
  gtk_widget_set_margin_start (GTK_WIDGET (footer), 12);
  gtk_widget_set_margin_end (GTK_WIDGET (footer), 12);
  gtk_widget_set_margin_top (GTK_WIDGET (footer), 8);
  gtk_widget_set_margin_bottom (GTK_WIDGET (footer), 8);

  /* Settings button */
  GtkButton *settings = GTK_BUTTON (gtk_button_new ());
  gtk_button_set_icon_name (settings, "emblem-system-symbolic");
  gtk_widget_set_tooltip_text (GTK_WIDGET (settings), "Settings");
  gtk_widget_add_css_class (GTK_WIDGET (settings), "flat");
  gtk_box_append (footer, GTK_WIDGET (settings));

  GtkLabel *label = GTK_LABEL (gtk_label_new ("Settings"));
  gtk_label_set_xalign (label, 0.0);
  gtk_widget_set_hexpand (GTK_WIDGET (label), TRUE);
  gtk_box_append (footer, GTK_WIDGET (label));

  /* Avatar circle */
  GtkLabel *avatar_label = GTK_LABEL (gtk_label_new ("W"));
  gtk_widget_add_css_class (GTK_WIDGET (avatar_label), "title-4");

  GtkBox *avatar = GTK_BOX (gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0));
  gtk_widget_set_size_request (GTK_WIDGET (avatar), 28, 28);
  gtk_widget_set_halign (GTK_WIDGET (avatar), GTK_ALIGN_CENTER);
  gtk_widget_set_valign (GTK_WIDGET (avatar), GTK_ALIGN_CENTER);
  gtk_widget_add_css_class (GTK_WIDGET (avatar), "accent");
  gtk_widget_add_css_class (GTK_WIDGET (avatar), "circular");
  gtk_box_append (avatar, GTK_WIDGET (avatar_label));
  gtk_box_append (footer, GTK_WIDGET (avatar));

  /* Top separator */
  GtkSeparator *sep = GTK_SEPARATOR (gtk_separator_new (GTK_ORIENTATION_HORIZONTAL));
  GtkBox *container = GTK_BOX (gtk_box_new (GTK_ORIENTATION_VERTICAL, 0));
  gtk_box_append (container, GTK_WIDGET (sep));
  gtk_box_append (container, GTK_WIDGET (footer));

  return GTK_WIDGET (container);
}

static void
wk_sidebar_constructed (GObject *object)
{
  WkSidebar *self = WK_SIDEBAR (object);

  G_OBJECT_CLASS (wk_sidebar_parent_class)->constructed (object);

  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_VERTICAL);
  gtk_widget_set_size_request (GTK_WIDGET (self), 200, -1);

  /* Sidebar header bar (no title, just branding space) */
  AdwHeaderBar *header = ADW_HEADER_BAR (adw_header_bar_new ());
  adw_header_bar_set_show_title (header, FALSE);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (header));

  /* Workspace search */
  self->search = GTK_SEARCH_ENTRY (gtk_search_entry_new ());
  gtk_widget_set_margin_start (GTK_WIDGET (self->search), 12);
  gtk_widget_set_margin_end (GTK_WIDGET (self->search), 12);
  gtk_widget_set_margin_bottom (GTK_WIDGET (self->search), 8);
  gtk_entry_set_placeholder_text (GTK_ENTRY (self->search),
                                  "Search tabs, spaces, history");
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (self->search));

  /* Tab list */
  self->tab_list = GTK_LIST_BOX (gtk_list_box_new ());
  gtk_list_box_set_selection_mode (self->tab_list, GTK_SELECTION_SINGLE);
  gtk_widget_add_css_class (GTK_WIDGET (self->tab_list), "navigation-sidebar");

  /* WORKSPACE section */
  gtk_list_box_append (self->tab_list,
                       make_section_header ("WORKSPACE"));
  gtk_list_box_append (self->tab_list,
                       make_sidebar_row ("tab-new-symbolic", "New Tab"));

  /* SPACES section */
  gtk_list_box_append (self->tab_list,
                       make_section_header ("SPACES"));
  gtk_list_box_append (self->tab_list,
                       make_sidebar_row ("view-grid-symbolic", "Personal"));
  gtk_list_box_append (self->tab_list,
                       make_sidebar_row ("view-grid-symbolic", "Work"));

  GtkScrolledWindow *scroll = GTK_SCROLLED_WINDOW (gtk_scrolled_window_new ());
  gtk_scrolled_window_set_policy (scroll, GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
  gtk_scrolled_window_set_child (scroll, GTK_WIDGET (self->tab_list));
  gtk_widget_set_vexpand (GTK_WIDGET (scroll), TRUE);
  gtk_box_append (GTK_BOX (self), GTK_WIDGET (scroll));

  /* Footer */
  gtk_box_append (GTK_BOX (self), build_footer ());
}

static void
wk_sidebar_class_init (WkSidebarClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  object_class->constructed = wk_sidebar_constructed;
}

static void
wk_sidebar_init (WkSidebar *self)
{
}

WkSidebar *
wk_sidebar_new (void)
{
  return g_object_new (WK_TYPE_SIDEBAR, NULL);
}
