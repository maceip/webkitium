// Windows DLL export stamp for browser/webauthn/WebAuthnBridgeC.h.

#include <cstdint>

extern "C" {

struct WkWebAuthn;

WkWebAuthn* wk_webauthn_create(void);
void        wk_webauthn_destroy(WkWebAuthn*);
int         wk_webauthn_is_initialized(const WkWebAuthn*);
int         wk_webauthn_request_count(const WkWebAuthn*);
int         wk_webauthn_rejection_count(const WkWebAuthn*);

__declspec(dllexport) WkWebAuthn* wk_webauthn_create_export(void) { return wk_webauthn_create(); }
__declspec(dllexport) void wk_webauthn_destroy_export(WkWebAuthn* h) { wk_webauthn_destroy(h); }
__declspec(dllexport) int wk_webauthn_is_initialized_export(const WkWebAuthn* h) { return wk_webauthn_is_initialized(h); }
__declspec(dllexport) int wk_webauthn_request_count_export(const WkWebAuthn* h) { return wk_webauthn_request_count(h); }
__declspec(dllexport) int wk_webauthn_rejection_count_export(const WkWebAuthn* h) { return wk_webauthn_rejection_count(h); }

}
