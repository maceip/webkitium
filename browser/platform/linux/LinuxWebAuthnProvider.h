#pragma once

#ifdef __linux__

#include "webauthn/WebAuthnController.h"

#include <string>

namespace ng {

struct LinuxWebAuthnProviderOptions {
    std::string devicePath;
    std::string pin;
    bool debug { false };
};

class LinuxWebAuthnProvider final : public PlatformWebAuthnProvider {
public:
    explicit LinuxWebAuthnProvider(LinuxWebAuthnProviderOptions = {});

    Result<WebAuthnAssertion> getAssertion(const WebAuthnGetRequest&) final;
    Result<WebAuthnAttestation> makeCredential(const WebAuthnCreateRequest&) final;

    static bool isAvailable();

private:
    LinuxWebAuthnProviderOptions m_options;
};

namespace linux_webauthn {

int assertionExtensionFlags(const WebAuthnGetRequest&);
int credentialExtensionFlags(const WebAuthnCreateRequest&);
std::string discoverFirstDevicePath();

} // namespace linux_webauthn

} // namespace ng

#endif
