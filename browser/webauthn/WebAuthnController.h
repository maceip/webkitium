#pragma once

#include "core/Origin.h"
#include "core/Result.h"

#include <chrono>
#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace ng {

using ByteVector = std::vector<uint8_t>;

enum class UserVerificationRequirement {
    Required,
    Preferred,
    Discouraged,
};

enum class AuthenticatorAttachment {
    Any,
    Platform,
    CrossPlatform,
};

enum class AttestationConveyancePreference {
    None,
    Indirect,
    Direct,
};

struct PublicKeyCredentialDescriptor {
    std::string type;
    ByteVector id;
    std::vector<std::string> transports;
};

struct WebAuthnGetRequest {
    FrameContext frame;
    std::string relyingPartyId;
    ByteVector challenge;
    std::vector<PublicKeyCredentialDescriptor> allowCredentials;
    UserVerificationRequirement userVerification { UserVerificationRequirement::Preferred };
    AuthenticatorAttachment attachment { AuthenticatorAttachment::Any };
    std::chrono::milliseconds timeout { 60000 };
};

struct WebAuthnAssertion {
    ByteVector credentialId;
    ByteVector authenticatorData;
    ByteVector clientDataJSON;
    ByteVector signature;
    ByteVector userHandle;
};

struct WebAuthnCreateRequest {
    FrameContext frame;
    std::string relyingPartyId;
    std::string relyingPartyName;
    ByteVector challenge;
    ByteVector userId;
    std::string userName;
    std::string userDisplayName;
    std::vector<int32_t> pubKeyCredAlgorithms;
    std::vector<PublicKeyCredentialDescriptor> excludeCredentials;
    UserVerificationRequirement userVerification { UserVerificationRequirement::Preferred };
    AuthenticatorAttachment attachment { AuthenticatorAttachment::Any };
    bool residentKey { false };
    AttestationConveyancePreference attestation { AttestationConveyancePreference::None };
    std::chrono::milliseconds timeout { 60000 };
};

struct WebAuthnAttestation {
    ByteVector credentialId;
    ByteVector clientDataJSON;
    ByteVector attestationObject;
};

class PlatformWebAuthnProvider {
public:
    virtual ~PlatformWebAuthnProvider() = default;
    virtual Result<WebAuthnAssertion> getAssertion(const WebAuthnGetRequest&) = 0;
    virtual Result<WebAuthnAttestation> makeCredential(const WebAuthnCreateRequest&) = 0;
};

class WebAuthnController {
public:
    explicit WebAuthnController(PlatformWebAuthnProvider&);

    Result<WebAuthnAssertion> get(const WebAuthnGetRequest&);
    Result<WebAuthnAttestation> make(WebAuthnCreateRequest);

private:
    Result<void> validateGetRequest(const WebAuthnGetRequest&) const;
    Result<void> validateCreateRequest(const WebAuthnCreateRequest&) const;

    PlatformWebAuthnProvider& m_provider;
};

} // namespace ng

