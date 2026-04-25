#include "webauthn/WebAuthnBridgeC.h"

#include <new>

#include "webauthn/WebAuthnController.h"

extern "C" {

namespace {

// Inactive provider: always returns NotAllowedError.  The bridge is
// "wired" because the controller exists; "inactive" because every get()
// would short-circuit with this stub.  Real platform providers
// (Windows Hello, Touch ID, Android BiometricPrompt) replace this.
class InactivePlatformProvider final : public ng::PlatformWebAuthnProvider {
public:
    ng::Result<ng::WebAuthnAssertion>
    getAssertion(const ng::WebAuthnGetRequest&) final {
        return ng::Result<ng::WebAuthnAssertion>::fail(
            ng::Error{ ng::ErrorCode::PermissionDenied,
                       "WebAuthn is wired but inactive in this build." });
    }
};

}  // namespace

struct WkWebAuthn {
    InactivePlatformProvider provider;
    ng::WebAuthnController   controller;

    WkWebAuthn() : controller(provider) {}
};

WkWebAuthn* wk_webauthn_create(void) {
    return new (std::nothrow) WkWebAuthn{};
}

void wk_webauthn_destroy(WkWebAuthn* h) {
    delete h;
}

int wk_webauthn_is_initialized(const WkWebAuthn* h) {
    return h ? 1 : 0;
}

int wk_webauthn_request_count(const WkWebAuthn*) {
    // Activated state will track this; wired-but-inactive returns 0.
    return 0;
}

int wk_webauthn_rejection_count(const WkWebAuthn*) {
    return 0;
}

}  // extern "C"
