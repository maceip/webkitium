#include "wk-application.h"
#include "wk-services.h"
#include "wk-window.h"

struct _WkApplication {
  AdwApplication parent;

  /* Wired-but-inactive: ExtensionRegistry + sync stub +
   * WebAuthnController, constructed once at app startup.  No surface
   * invokes them yet; future Settings pages read state from here. */
  WkServices *services;
};

G_DEFINE_TYPE (WkApplication, wk_application, ADW_TYPE_APPLICATION)

static void
wk_application_activate (GApplication *app)
{
  WkWindow *win = wk_window_new (WK_APPLICATION (app));
  gtk_window_present (GTK_WINDOW (win));
}

static void
wk_application_startup (GApplication *app)
{
  G_APPLICATION_CLASS (wk_application_parent_class)->startup (app);

  WkApplication *self = WK_APPLICATION (app);
  self->services = wk_services_new ();
  if (self->services == NULL)
    g_warning ("WkServices failed to initialize; running without browser controllers");
}

static void
wk_application_shutdown (GApplication *app)
{
  WkApplication *self = WK_APPLICATION (app);
  g_clear_pointer (&self->services, wk_services_free);

  G_APPLICATION_CLASS (wk_application_parent_class)->shutdown (app);
}

static void
wk_application_class_init (WkApplicationClass *klass)
{
  GApplicationClass *app_class = G_APPLICATION_CLASS (klass);
  app_class->activate = wk_application_activate;
  app_class->startup  = wk_application_startup;
  app_class->shutdown = wk_application_shutdown;
}

static void
wk_application_init (WkApplication *self)
{
  self->services = NULL;
}

WkApplication *
wk_application_new (void)
{
  return g_object_new (WK_TYPE_APPLICATION,
                       "application-id", "dev.webkitium.Browser",
                       "flags", G_APPLICATION_DEFAULT_FLAGS,
                       NULL);
}
