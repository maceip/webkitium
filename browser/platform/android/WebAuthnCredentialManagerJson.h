#pragma once

#include "webauthn/WebAuthnController.h"

#include <string>

namespace ng {
namespace android_webauthn {

// JSON strings for androidx.credentials / Credential Manager:
// - get:  GetPublicKeyCredentialOption(here)
// - make: CreatePublicKeyCredentialRequest(here)

std::string androidApkKeyHashOrigin(const ByteVector& signingCertificateSha256);

std::string buildPublicKeyCredentialRequestOptionsJson(const WebAuthnGetRequest&);
std::string buildPublicKeyCredentialCreationOptionsJson(const WebAuthnCreateRequest&);

} // namespace android_webauthn
} // namespace ng
