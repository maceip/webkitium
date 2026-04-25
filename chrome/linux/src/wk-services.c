#include "wk-services.h"

#include <stdlib.h>

#include "extensions/ExtensionBridgeC.h"
#include "sync/SyncBridgeC.h"
#include "webauthn/WebAuthnBridgeC.h"

struct WkServices {
  WkExtensionRegistry *extensions;
  WkSyncStatus        *sync;
  WkWebAuthn          *webauthn;
};

WkServices *
wk_services_new (void)
{
  WkServices *self = calloc (1, sizeof (WkServices));
  if (self == NULL)
    return NULL;

  self->extensions = wk_extensions_create ();
  self->sync       = wk_sync_create ();
  self->webauthn   = wk_webauthn_create ();

  if (self->extensions == NULL || self->sync == NULL || self->webauthn == NULL) {
    wk_services_free (self);
    return NULL;
  }
  return self;
}

void
wk_services_free (WkServices *self)
{
  if (self == NULL)
    return;
  if (self->extensions != NULL)
    wk_extensions_destroy (self->extensions);
  if (self->sync != NULL)
    wk_sync_destroy (self->sync);
  if (self->webauthn != NULL)
    wk_webauthn_destroy (self->webauthn);
  free (self);
}

int
wk_services_extension_count (WkServices *self)
{
  return self != NULL ? wk_extensions_count (self->extensions) : 0;
}

int
wk_services_sync_record_count (WkServices *self)
{
  return self != NULL ? wk_sync_record_count (self->sync) : 0;
}

int64_t
wk_services_sync_current_version (WkServices *self)
{
  return self != NULL ? wk_sync_current_version (self->sync) : -1;
}

bool
wk_services_webauthn_ready (WkServices *self)
{
  return self != NULL && wk_webauthn_is_initialized (self->webauthn) != 0;
}

int
wk_services_webauthn_request_count (WkServices *self)
{
  return self != NULL ? wk_webauthn_request_count (self->webauthn) : 0;
}

int
wk_services_webauthn_rejection_count (WkServices *self)
{
  return self != NULL ? wk_webauthn_rejection_count (self->webauthn) : 0;
}
