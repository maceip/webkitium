#include "webauthn/WebAuthnController.h"

namespace ng {

WebAuthnController::WebAuthnController(PlatformWebAuthnProvider& provider)
    : m_provider(provider)
{
}

Result<WebAuthnAssertion> WebAuthnController::get(const WebAuthnGetRequest& request)
{
    auto validation = validateGetRequest(request);
    if (!validation)
        return Result<WebAuthnAssertion>::fail(validation.error());

    return m_provider.getAssertion(request);
}

Result<WebAuthnAttestation> WebAuthnController::make(WebAuthnCreateRequest request)
{
    if (request.pubKeyCredAlgorithms.empty()) {
        request.pubKeyCredAlgorithms.push_back(-7); // ES256
        request.pubKeyCredAlgorithms.push_back(-257); // RS256
    }

    auto validation = validateCreateRequest(request);
    if (!validation)
        return Result<WebAuthnAttestation>::fail(validation.error());

    return m_provider.makeCredential(request);
}

Result<void> WebAuthnController::validateGetRequest(const WebAuthnGetRequest& request) const
{
    if (!request.frame.origin.isPotentiallyTrustworthy())
        return Result<void>::fail({ ErrorCode::PermissionDenied, "WebAuthn requires a trustworthy origin" });
    if (request.relyingPartyId.empty())
        return Result<void>::fail({ ErrorCode::InvalidArgument, "relying party id is required" });
    if (request.challenge.size() < 16)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "challenge must be at least 16 bytes" });
    if (request.timeout.count() <= 0)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "timeout must be positive" });
    if (!request.frame.hasTransientUserActivation)
        return Result<void>::fail({ ErrorCode::PermissionDenied, "WebAuthn request requires user activation" });

    return Result<void>::ok();
}

Result<void> WebAuthnController::validateCreateRequest(const WebAuthnCreateRequest& request) const
{
    if (!request.frame.origin.isPotentiallyTrustworthy())
        return Result<void>::fail({ ErrorCode::PermissionDenied, "WebAuthn requires a trustworthy origin" });
    if (request.relyingPartyId.empty())
        return Result<void>::fail({ ErrorCode::InvalidArgument, "relying party id is required" });
    if (request.relyingPartyName.empty())
        return Result<void>::fail({ ErrorCode::InvalidArgument, "relying party name is required" });
    if (request.challenge.size() < 16)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "challenge must be at least 16 bytes" });
    if (request.timeout.count() <= 0)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "timeout must be positive" });
    if (!request.frame.hasTransientUserActivation)
        return Result<void>::fail({ ErrorCode::PermissionDenied, "WebAuthn request requires user activation" });
    if (request.userId.size() > 64)
        return Result<void>::fail({ ErrorCode::InvalidArgument, "user id exceeds 64 bytes" });

    return Result<void>::ok();
}

} // namespace ng

