#include "platform/android/AndroidWebAuthnProvider.h"

#ifdef __ANDROID__

#include "platform/android/WebAuthnCredentialManagerJson.h"

#include <utility>

namespace ng {

std::string AndroidAppInfo::origin() const
{
    return android_webauthn::androidApkKeyHashOrigin(signingCertificateSha256);
}

AndroidWebAuthnProvider::AndroidWebAuthnProvider(AndroidWebAuthnBridge& bridge, AndroidAppInfo appInfo)
    : m_bridge(bridge)
    , m_appInfo(std::move(appInfo))
{
}

Result<WebAuthnAssertion> AndroidWebAuthnProvider::getAssertion(const WebAuthnGetRequest& request)
{
    if (m_appInfo.packageName.empty())
        return Result<WebAuthnAssertion>::fail({ ErrorCode::InvalidArgument, "Android WebAuthn requires an app package name" });
    if (m_appInfo.signingCertificateSha256.empty())
        return Result<WebAuthnAssertion>::fail({ ErrorCode::InvalidArgument, "Android WebAuthn requires the signing certificate SHA-256 hash" });

    AndroidWebAuthnAssertionRequest credentialRequest;
    credentialRequest.requestJson = android_webauthn::buildPublicKeyCredentialRequestOptionsJson(request);
    credentialRequest.appInfo = m_appInfo;

    return m_bridge.getAssertion(credentialRequest);
}

Result<WebAuthnAttestation> AndroidWebAuthnProvider::makeCredential(const WebAuthnCreateRequest& request)
{
    if (m_appInfo.packageName.empty())
        return Result<WebAuthnAttestation>::fail({ ErrorCode::InvalidArgument, "Android WebAuthn requires an app package name" });
    if (m_appInfo.signingCertificateSha256.empty())
        return Result<WebAuthnAttestation>::fail({ ErrorCode::InvalidArgument, "Android WebAuthn requires the signing certificate SHA-256 hash" });

    AndroidWebAuthnCreationRequest credentialRequest;
    credentialRequest.requestJson = android_webauthn::buildPublicKeyCredentialCreationOptionsJson(request);
    credentialRequest.appInfo = m_appInfo;

    return m_bridge.makeCredential(credentialRequest);
}

} // namespace ng

#endif
