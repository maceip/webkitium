#pragma once

#ifdef _WIN32

#include "webauthn/WebAuthnController.h"

#include <windows.h>

namespace ng {

/// Windows-specific options for `WindowsWebAuthnProvider` (InPrivate / WebView guest profile, etc.).
struct WindowsWebAuthnProviderOptions {
    /// Forwarded to `WEBAUTHN_AUTHENTICATOR_*_OPTIONS.bBrowserInPrivateMode` when the OS supports it
    /// (get assertion options v6+, make credential options v5+).
    bool inPrivateBrowser { false };
};

class WindowsWebAuthnProvider final : public PlatformWebAuthnProvider {
public:
    explicit WindowsWebAuthnProvider(HWND parentWindow, WindowsWebAuthnProviderOptions options = {});

    Result<WebAuthnAssertion> getAssertion(const WebAuthnGetRequest&) final;
    Result<WebAuthnAttestation> makeCredential(const WebAuthnCreateRequest&) final;

    /// `WebAuthNGetApiVersionNumber()`. Zero means WebAuthn is not supported on this system.
    static DWORD apiVersion();

    /// `WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable` (Windows Hello–class authenticator).
    static Result<bool> isUserVerifyingPlatformAuthenticatorAvailable();

private:
    HWND m_parentWindow;
    WindowsWebAuthnProviderOptions m_options;
};

} // namespace ng

#endif
