#pragma once

#ifdef __APPLE__
#include <TargetConditionals.h>
#if TARGET_OS_OSX

#include "webauthn/WebAuthnController.h"

namespace ng {

/// Native WebAuthn via AuthenticationServices: platform authenticator (passkeys) and
/// cross-platform **security keys** (`ASAuthorizationSecurityKeyPublicKeyCredentialProvider`).
///
/// `presentationWindow` is an `NSWindow*` used as the `ASAuthorization` presentation anchor
/// (`__bridge void*` from ObjC). May be null; the provider falls back to key/main window.
///
/// @note `getAssertion` and `makeCredential` must be called from a **non-main** thread.
/// They dispatch UI work to the main queue and block the calling thread until completion.
class MacOSWebAuthnProvider final : public PlatformWebAuthnProvider {
public:
    explicit MacOSWebAuthnProvider(void* presentationWindow = nullptr);

    Result<WebAuthnAssertion> getAssertion(const WebAuthnGetRequest&) final;
    Result<WebAuthnAttestation> makeCredential(const WebAuthnCreateRequest&) final;

private:
    void* m_presentationWindow;
};

} // namespace ng

#endif // TARGET_OS_OSX
#endif // __APPLE__
