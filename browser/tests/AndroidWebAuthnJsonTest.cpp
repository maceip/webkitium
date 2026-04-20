#include "platform/android/WebAuthnCredentialManagerJson.h"

#include <cassert>
#include <string>

namespace {

ng::FrameContext trustworthyFrame()
{
    ng::FrameContext frame;
    frame.origin = { "https", "example.com", 0 };
    frame.topLevelOrigin = frame.origin;
    frame.isTopLevel = true;
    frame.hasTransientUserActivation = true;
    return frame;
}

void requireContains(const std::string& haystack, const std::string& needle)
{
    assert(haystack.find(needle) != std::string::npos);
}

void exerciseAndroidOrigin()
{
    const ng::ByteVector digest = { 0xfb, 0xff, 0x00, 0x10 };
    assert(ng::android_webauthn::androidApkKeyHashOrigin(digest) == "android:apk-key-hash:-_8AEA");
}

void exerciseGetRequestJson()
{
    ng::WebAuthnGetRequest request;
    request.frame = trustworthyFrame();
    request.relyingPartyId = "example.com";
    request.challenge = { 1, 2, 3, 4 };
    request.allowCredentials.push_back({ "public-key", { 5, 6, 7 }, { "internal", "hybrid" } });
    request.userVerification = ng::UserVerificationRequirement::Required;

    const std::string json = ng::android_webauthn::buildPublicKeyCredentialRequestOptionsJson(request);
    requireContains(json, "\"challenge\":\"AQIDBA\"");
    requireContains(json, "\"rpId\":\"example.com\"");
    requireContains(json, "\"allowCredentials\":[{\"type\":\"public-key\",\"id\":\"BQYH\",\"transports\":[\"internal\",\"hybrid\"]}]");
    requireContains(json, "\"userVerification\":\"required\"");
}

void exerciseCreateRequestJson()
{
    ng::WebAuthnCreateRequest request;
    request.frame = trustworthyFrame();
    request.relyingPartyId = "example.com";
    request.relyingPartyName = "Example";
    request.challenge = { 8, 9, 10, 11 };
    request.userId = { 12, 13, 14 };
    request.userName = "user@example.com";
    request.userDisplayName = "Example User";
    request.pubKeyCredAlgorithms = { -7, -257 };
    request.excludeCredentials.push_back({ "public-key", { 15, 16, 17 }, { } });
    request.attachment = ng::AuthenticatorAttachment::Platform;
    request.residentKey = true;
    request.attestation = ng::AttestationConveyancePreference::Direct;

    const std::string json = ng::android_webauthn::buildPublicKeyCredentialCreationOptionsJson(request);
    requireContains(json, "\"challenge\":\"CAkKCw\"");
    requireContains(json, "\"rp\":{\"name\":\"Example\",\"id\":\"example.com\"}");
    requireContains(json, "\"user\":{\"id\":\"DA0O\",\"name\":\"user@example.com\",\"displayName\":\"Example User\"}");
    requireContains(json, "\"pubKeyCredParams\":[{\"type\":\"public-key\",\"alg\":-7},{\"type\":\"public-key\",\"alg\":-257}]");
    requireContains(json, "\"excludeCredentials\":[{\"type\":\"public-key\",\"id\":\"DxAR\"}]");
    requireContains(json, "\"authenticatorAttachment\":\"platform\"");
    requireContains(json, "\"residentKey\":\"required\"");
    requireContains(json, "\"attestation\":\"direct\"");
}

} // namespace

int main()
{
    exerciseAndroidOrigin();
    exerciseGetRequestJson();
    exerciseCreateRequestJson();
    return 0;
}
