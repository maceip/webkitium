// C ABI for browser/webauthn/ -- wired-but-inactive surface for shells.
//
// Holds a WebAuthnController over a stub PlatformWebAuthnProvider so the
// runtime is constructed and reachable from each shell, but actual
// ceremony invocation is deferred until the platform-specific
// authenticator is bridged in.

#ifndef WEBKITIUM_WEBAUTHN_BRIDGE_C_H_
#define WEBKITIUM_WEBAUTHN_BRIDGE_C_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct WkWebAuthn WkWebAuthn;

WkWebAuthn* wk_webauthn_create(void);
void        wk_webauthn_destroy(WkWebAuthn*);

// 1 if the controller was constructed successfully, 0 otherwise.
int         wk_webauthn_is_initialized(const WkWebAuthn*);

// Counters reserved for the activated-state future.  Always 0 in
// the wired-but-inactive state.
int         wk_webauthn_request_count(const WkWebAuthn*);
int         wk_webauthn_rejection_count(const WkWebAuthn*);

#ifdef __cplusplus
}
#endif

#endif  // WEBKITIUM_WEBAUTHN_BRIDGE_C_H_
