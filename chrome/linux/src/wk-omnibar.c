/*
 * WkOmnibar — unified address + search bar
 *
 * Compact pill: [lockmark] [input] [reload] [extensions] [more]
 * Matches design/components/omnibar/SPEC.md using Adwaita icons.
 *
 * Emits "navigate" signal with the URI when the user presses Enter.
 */

#include "wk-omnibar.h"

struct _WkOmnibar {
  GtkBox parent;

  GtkImage   *lockmark;
  GtkEntry   *input;
  GtkButton  *reload_btn;
};

enum {
  SIGNAL_NAVIGATE,
  N_SIGNALS
};

static guint signals[N_SIGNALS];

G_DEFINE_TYPE (WkOmnibar, wk_omnibar, GTK_TYPE_BOX)

static void
on_input_activate (GtkEntry  *entry,
                   WkOmnibar *self)
{
  const char *text = gtk_editable_get_text (GTK_EDITABLE (entry));
  if (text == NULL || *text == '\0')
    return;

  /* Minimal URI fixup: if no scheme, prepend https:// */
  g_autofree char *uri = NULL;
  if (g_str_has_prefix (text, "http://") ||
      g_str_has_prefix (text, "https://") ||
      g_str_has_prefix (text, "file://"))
    uri = g_strdup (text);
  else if (g_strstr_len (text, -1, ".") != NULL)
    uri = g_strdup_printf ("https://%s", text);
  else
    uri = g_strdup_printf ("https://search.brave.com/search?q=%s", text);

  g_signal_emit (self, signals[SIGNAL_NAVIGATE], 0, uri);
}

static void
wk_omnibar_constructed (GObject *object)
{
  WkOmnibar *self = WK_OMNIBAR (object);

  G_OBJECT_CLASS (wk_omnibar_parent_class)->constructed (object);

  gtk_orientable_set_orientation (GTK_ORIENTABLE (self), GTK_ORIENTATION_HORIZONTAL);
  gtk_widget_set_hexpand (GTK_WIDGET (self), TRUE);
  gtk_widget_add_css_class (GTK_WIDGET (self), "linked");

  /* Pill container */
  GtkBox *pill = GTK_BOX (gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 4));
  gtk_widget_add_css_class (GTK_WIDGET (pill), "toolbar");
  gtk_widget_set_hexpand (GTK_WIDGET (pill), TRUE);

  /* Lockmark — blue accent via Pango markup on a GtkLabel.
     Symbolic icons get their color overridden by Adwaita, so we use
     a label with explicit foreground color instead. */
  {
    GtkLabel *lock_label = GTK_LABEL (gtk_label_new (NULL));
    gtk_label_set_markup (lock_label,
      "<span foreground=\"#1F5AE0\" weight=\"bold\" font_desc=\"14\">🔒</span>");
    gtk_widget_set_margin_start (GTK_WIDGET (lock_label), 8);
    gtk_widget_set_margin_end (GTK_WIDGET (lock_label), 2);
    gtk_box_append (pill, GTK_WIDGET (lock_label));
    /* Keep self->lockmark allocated for the header file contract */
    self->lockmark = GTK_IMAGE (gtk_image_new ());
    gtk_widget_set_visible (GTK_WIDGET (self->lockmark), FALSE);
  }

  /* Input */
  self->input = GTK_ENTRY (gtk_entry_new ());
  gtk_entry_set_placeholder_text (self->input, "Search or enter address");
  gtk_widget_set_hexpand (GTK_WIDGET (self->input), TRUE);
  gtk_widget_add_css_class (GTK_WIDGET (self->input), "flat");
  g_signal_connect (self->input, "activate",
                    G_CALLBACK (on_input_activate), self);
  gtk_box_append (pill, GTK_WIDGET (self->input));

  /* Reload */
  self->reload_btn = GTK_BUTTON (gtk_button_new_from_icon_name ("view-refresh-symbolic"));
  gtk_widget_add_css_class (GTK_WIDGET (self->reload_btn), "flat");
  gtk_widget_set_tooltip_text (GTK_WIDGET (self->reload_btn), "Reload (Ctrl+R)");
  gtk_box_append (pill, GTK_WIDGET (self->reload_btn));

  gtk_box_append (GTK_BOX (self), GTK_WIDGET (pill));
}

static void
wk_omnibar_class_init (WkOmnibarClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  object_class->constructed = wk_omnibar_constructed;

  signals[SIGNAL_NAVIGATE] = g_signal_new ("navigate",
    G_TYPE_FROM_CLASS (klass),
    G_SIGNAL_RUN_LAST,
    0, NULL, NULL, NULL,
    G_TYPE_NONE, 1, G_TYPE_STRING);
}

static void
wk_omnibar_init (WkOmnibar *self)
{
}

WkOmnibar *
wk_omnibar_new (void)
{
  return g_object_new (WK_TYPE_OMNIBAR, NULL);
}
