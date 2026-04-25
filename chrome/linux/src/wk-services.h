/* Process-wide holder for the wired-but-inactive controllers from
 * browser/.  GTK shell instantiates one in wk_application_init and
 * keeps it for the app lifetime.  No surface invokes the controllers
 * yet; counts will populate Settings pages when they land.
 *
 * Mirrors:
 *   chrome/windows/Platform/BrowserServices.cs
 *   chrome/macos/Sources/Webkitium/Services/BrowserServices.swift
 *   chrome/android/app/src/main/java/dev/webkitium/services/BrowserServices.kt
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkServices WkServices;

WkServices *wk_services_new (void);
void        wk_services_free (WkServices *self);

int         wk_services_extension_count (WkServices *self);

int         wk_services_sync_record_count (WkServices *self);
int64_t     wk_services_sync_current_version (WkServices *self);

bool        wk_services_webauthn_ready (WkServices *self);
int         wk_services_webauthn_request_count (WkServices *self);
int         wk_services_webauthn_rejection_count (WkServices *self);

#ifdef __cplusplus
}
#endif
