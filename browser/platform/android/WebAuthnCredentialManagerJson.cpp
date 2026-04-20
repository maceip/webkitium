#include "platform/android/WebAuthnCredentialManagerJson.h"

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <sstream>
#include <vector>

namespace ng {
namespace android_webauthn {
namespace detail {

std::string jsonEscape(const std::string& s)
{
    std::string out;
    out.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) {
        case '\\':
            out += "\\\\";
            break;
        case '"':
            out += "\\\"";
            break;
        case '\b':
            out += "\\b";
            break;
        case '\f':
            out += "\\f";
            break;
        case '\n':
            out += "\\n";
            break;
        case '\r':
            out += "\\r";
            break;
        case '\t':
            out += "\\t";
            break;
        default:
            if (c < 0x20) {
                char escaped[7];
                snprintf(escaped, sizeof(escaped), "\\u%04X", c);
                out += escaped;
            } else {
                out += static_cast<char>(c);
            }
            break;
        }
    }
    return out;
}

std::string base64UrlEncode(const ByteVector& bytes)
{
    static const char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

    std::string out;
    out.reserve(((bytes.size() + 2) / 3) * 4);

    size_t i = 0;
    while (i + 2 < bytes.size()) {
        uint32_t triple = (static_cast<uint32_t>(bytes[i]) << 16) | (static_cast<uint32_t>(bytes[i + 1]) << 8)
            | static_cast<uint32_t>(bytes[i + 2]);
        out += table[(triple >> 18) & 63];
        out += table[(triple >> 12) & 63];
        out += table[(triple >> 6) & 63];
        out += table[triple & 63];
        i += 3;
    }

    const size_t remaining = bytes.size() - i;
    if (remaining == 1) {
        uint32_t triple = static_cast<uint32_t>(bytes[i]) << 16;
        out += table[(triple >> 18) & 63];
        out += table[(triple >> 12) & 63];
    } else if (remaining == 2) {
        uint32_t triple = (static_cast<uint32_t>(bytes[i]) << 16) | (static_cast<uint32_t>(bytes[i + 1]) << 8);
        out += table[(triple >> 18) & 63];
        out += table[(triple >> 12) & 63];
        out += table[(triple >> 6) & 63];
    }

    return out;
}

const char* userVerificationToJson(UserVerificationRequirement uv)
{
    switch (uv) {
    case UserVerificationRequirement::Required:
        return "required";
    case UserVerificationRequirement::Preferred:
        return "preferred";
    case UserVerificationRequirement::Discouraged:
        return "discouraged";
    }
    return "preferred";
}

const char* authenticatorAttachmentToJson(AuthenticatorAttachment attachment)
{
    switch (attachment) {
    case AuthenticatorAttachment::Platform:
        return "platform";
    case AuthenticatorAttachment::CrossPlatform:
        return "cross-platform";
    case AuthenticatorAttachment::Any:
        return "";
    }
    return "";
}

const char* attestationToJson(AttestationConveyancePreference attestation)
{
    switch (attestation) {
    case AttestationConveyancePreference::None:
        return "none";
    case AttestationConveyancePreference::Indirect:
        return "indirect";
    case AttestationConveyancePreference::Direct:
        return "direct";
    }
    return "none";
}

const char* residentKeyToJson(bool requireResident)
{
    return requireResident ? "required" : "preferred";
}

void appendStringArray(std::ostringstream& json, const std::vector<std::string>& values)
{
    json << '[';
    for (size_t i = 0; i < values.size(); ++i) {
        if (i)
            json << ',';
        json << '"' << jsonEscape(values[i]) << '"';
    }
    json << ']';
}

void appendCredentialDescriptor(std::ostringstream& json, const PublicKeyCredentialDescriptor& credential)
{
    json << "{\"type\":\"public-key\",\"id\":\"" << base64UrlEncode(credential.id) << "\"";
    if (!credential.transports.empty()) {
        json << ",\"transports\":";
        appendStringArray(json, credential.transports);
    }
    json << '}';
}

void appendCredentialDescriptorList(std::ostringstream& json, const std::vector<PublicKeyCredentialDescriptor>& credentials)
{
    json << '[';
    bool firstCredential = true;
    for (const auto& credential : credentials) {
        if (credential.type != "public-key")
            continue;
        if (!firstCredential)
            json << ',';
        firstCredential = false;
        appendCredentialDescriptor(json, credential);
    }
    json << ']';
}

} // namespace detail

std::string androidApkKeyHashOrigin(const ByteVector& signingCertificateSha256)
{
    if (signingCertificateSha256.empty())
        return { };
    return "android:apk-key-hash:" + detail::base64UrlEncode(signingCertificateSha256);
}

std::string buildPublicKeyCredentialRequestOptionsJson(const WebAuthnGetRequest& request)
{
    std::ostringstream json;
    json << "{\"challenge\":\"" << detail::base64UrlEncode(request.challenge) << "\"";
    json << ",\"timeout\":" << std::max<std::chrono::milliseconds::rep>(0, request.timeout.count());
    json << ",\"rpId\":\"" << detail::jsonEscape(request.relyingPartyId) << "\"";

    json << ",\"allowCredentials\":";
    detail::appendCredentialDescriptorList(json, request.allowCredentials);

    json << ",\"userVerification\":\"" << detail::userVerificationToJson(request.userVerification) << "\"";
    json << '}';
    return json.str();
}

std::string buildPublicKeyCredentialCreationOptionsJson(const WebAuthnCreateRequest& request)
{
    std::ostringstream json;
    json << "{\"challenge\":\"" << detail::base64UrlEncode(request.challenge) << "\"";
    json << ",\"rp\":{\"name\":\"" << detail::jsonEscape(request.relyingPartyName) << "\",\"id\":\""
         << detail::jsonEscape(request.relyingPartyId) << "\"}";
    json << ",\"user\":{\"id\":\"" << detail::base64UrlEncode(request.userId) << "\",\"name\":\""
         << detail::jsonEscape(request.userName) << "\",\"displayName\":\""
         << detail::jsonEscape(request.userDisplayName) << "\"}";

    json << ",\"pubKeyCredParams\":[";
    for (size_t i = 0; i < request.pubKeyCredAlgorithms.size(); ++i) {
        if (i)
            json << ',';
        json << "{\"type\":\"public-key\",\"alg\":" << request.pubKeyCredAlgorithms[i] << '}';
    }
    json << ']';

    json << ",\"timeout\":" << std::max<std::chrono::milliseconds::rep>(0, request.timeout.count());
    json << ",\"excludeCredentials\":";
    detail::appendCredentialDescriptorList(json, request.excludeCredentials);

    json << ",\"authenticatorSelection\":{";
    bool wroteSelection = false;
    const char* attachment = detail::authenticatorAttachmentToJson(request.attachment);
    if (attachment[0]) {
        json << "\"authenticatorAttachment\":\"" << attachment << "\"";
        wroteSelection = true;
    }
    if (wroteSelection)
        json << ',';
    json << "\"residentKey\":\"" << detail::residentKeyToJson(request.residentKey) << "\"";
    json << ",\"requireResidentKey\":" << (request.residentKey ? "true" : "false");
    json << ",\"userVerification\":\"" << detail::userVerificationToJson(request.userVerification) << "\"";
    json << '}';

    json << ",\"attestation\":\"" << detail::attestationToJson(request.attestation) << "\"";
    json << '}';
    return json.str();
}

} // namespace android_webauthn
} // namespace ng
