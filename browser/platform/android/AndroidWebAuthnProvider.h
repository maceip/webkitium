#pragma once

#ifdef __ANDROID__

#include "webauthn/WebAuthnController.h"

#include <string>

namespace ng {

struct AndroidAppInfo {
    std::string packageName;
    ByteVector signingCertificateSha256;

    std::string origin() const;
};

// Pass to JNI for GetPublicKeyCredentialOption / CredentialManager.getCredential.
struct AndroidWebAuthnAssertionRequest {
    std::string requestJson;
    AndroidAppInfo appInfo;
};

// Pass to JNI for CreatePublicKeyCredentialRequest / CredentialManager.createCredential.
struct AndroidWebAuthnCreationRequest {
    std::string requestJson;
    AndroidAppInfo appInfo;
};

class AndroidWebAuthnBridge {
public:
    virtual ~AndroidWebAuthnBridge() = default;
    virtual Result<WebAuthnAssertion> getAssertion(const AndroidWebAuthnAssertionRequest&) = 0;
    virtual Result<WebAuthnAttestation> makeCredential(const AndroidWebAuthnCreationRequest&) = 0;
};

class AndroidWebAuthnProvider final : public PlatformWebAuthnProvider {
public:
    AndroidWebAuthnProvider(AndroidWebAuthnBridge&, AndroidAppInfo);

    Result<WebAuthnAssertion> getAssertion(const WebAuthnGetRequest&) final;
    Result<WebAuthnAttestation> makeCredential(const WebAuthnCreateRequest&) final;

private:
    AndroidWebAuthnBridge& m_bridge;
    AndroidAppInfo m_appInfo;
};

} // namespace ng

#endif
