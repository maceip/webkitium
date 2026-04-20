#include "platform/linux/LinuxWebAuthnProvider.h"

#ifdef __linux__

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <memory>
#include <sstream>
#include <utility>

#include <fido.h>

namespace ng {
namespace {

struct FidoDeleter {
    void operator()(fido_assert_t* value) const { fido_assert_free(&value); }
    void operator()(fido_cred_t* value) const { fido_cred_free(&value); }
    void operator()(fido_dev_t* value) const { fido_dev_free(&value); }
};

using AssertPtr = std::unique_ptr<fido_assert_t, FidoDeleter>;
using CredPtr = std::unique_ptr<fido_cred_t, FidoDeleter>;
using DevPtr = std::unique_ptr<fido_dev_t, FidoDeleter>;

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

std::string buildClientDataJson(const char* clientDataType, const FrameContext& frame, const ByteVector& challenge)
{
    std::ostringstream json;
    json << "{\"type\":\"" << clientDataType << "\",\"challenge\":\"" << base64UrlEncode(challenge)
         << "\",\"origin\":\"" << jsonEscape(frame.origin.serialize()) << '"';
    if (frame.includeCrossOriginClientDataMember())
        json << ",\"crossOrigin\":true";
    json << '}';
    return json.str();
}

fido_opt_t uvToFidoOpt(UserVerificationRequirement uv)
{
    switch (uv) {
    case UserVerificationRequirement::Required:
        return FIDO_OPT_TRUE;
    case UserVerificationRequirement::Discouraged:
        return FIDO_OPT_FALSE;
    case UserVerificationRequirement::Preferred:
        return FIDO_OPT_OMIT;
    }
    return FIDO_OPT_OMIT;
}

int coseAlgorithmForRequest(const WebAuthnCreateRequest& request)
{
    if (request.pubKeyCredAlgorithms.empty())
        return COSE_ES256;
    for (int32_t alg : request.pubKeyCredAlgorithms) {
        if (alg == COSE_ES256 || alg == COSE_RS256 || alg == COSE_EDDSA || alg == COSE_ES384)
            return static_cast<int>(alg);
    }
    return static_cast<int>(request.pubKeyCredAlgorithms.front());
}

Error errorFromFido(int code, const char* api)
{
    if (code == FIDO_OK)
        return { ErrorCode::None, { } };

    ErrorCode errorCode = ErrorCode::PlatformFailure;
    if (code == FIDO_ERR_INVALID_ARGUMENT)
        errorCode = ErrorCode::InvalidArgument;
    else if (code == FIDO_ERR_UNSUPPORTED_OPTION)
        errorCode = ErrorCode::Unsupported;
    else if (code == FIDO_ERR_ACTION_TIMEOUT || code == FIDO_ERR_KEEPALIVE_CANCEL)
        errorCode = ErrorCode::PermissionDenied;

    std::string message = api;
    message += ": ";
    message += fido_strerr(code);
    return { errorCode, std::move(message) };
}

template<typename ResultType>
Result<ResultType> failFido(int code, const char* api)
{
    return Result<ResultType>::fail(errorFromFido(code, api));
}

void appendCborTypeAndLength(ByteVector& out, uint8_t majorType, size_t length)
{
    uint8_t type = static_cast<uint8_t>(majorType << 5);
    if (length < 24) {
        out.push_back(static_cast<uint8_t>(type | length));
    } else if (length <= 0xff) {
        out.push_back(static_cast<uint8_t>(type | 24));
        out.push_back(static_cast<uint8_t>(length));
    } else if (length <= 0xffff) {
        out.push_back(static_cast<uint8_t>(type | 25));
        out.push_back(static_cast<uint8_t>((length >> 8) & 0xff));
        out.push_back(static_cast<uint8_t>(length & 0xff));
    } else {
        out.push_back(static_cast<uint8_t>(type | 26));
        out.push_back(static_cast<uint8_t>((length >> 24) & 0xff));
        out.push_back(static_cast<uint8_t>((length >> 16) & 0xff));
        out.push_back(static_cast<uint8_t>((length >> 8) & 0xff));
        out.push_back(static_cast<uint8_t>(length & 0xff));
    }
}

void appendCborText(ByteVector& out, const char* text)
{
    size_t length = std::strlen(text);
    appendCborTypeAndLength(out, 3, length);
    out.insert(out.end(), text, text + length);
}

void appendCborBytes(ByteVector& out, const unsigned char* ptr, size_t length)
{
    appendCborTypeAndLength(out, 2, length);
    if (ptr && length)
        out.insert(out.end(), ptr, ptr + length);
}

ByteVector buildAttestationObject(const fido_cred_t* cred)
{
    ByteVector out;
    out.push_back(0xa3);
    appendCborText(out, "fmt");
    appendCborText(out, fido_cred_fmt(cred) ? fido_cred_fmt(cred) : "none");
    appendCborText(out, "authData");
    appendCborBytes(out, fido_cred_authdata_ptr(cred), fido_cred_authdata_len(cred));
    appendCborText(out, "attStmt");
    const unsigned char* attStmt = fido_cred_attstmt_ptr(cred);
    size_t attStmtLen = fido_cred_attstmt_len(cred);
    if (attStmt && attStmtLen)
        out.insert(out.end(), attStmt, attStmt + attStmtLen);
    else
        out.push_back(0xa0);
    return out;
}

std::string resolveDevicePath(const LinuxWebAuthnProviderOptions& options)
{
    if (!options.devicePath.empty())
        return options.devicePath;
    return linux_webauthn::discoverFirstDevicePath();
}

Result<DevPtr> openDevice(const LinuxWebAuthnProviderOptions& options, int timeoutMs)
{
    const std::string path = resolveDevicePath(options);
    if (path.empty())
        return Result<DevPtr>::fail({ ErrorCode::NotFound, "no FIDO2 device found" });

    DevPtr dev(fido_dev_new());
    if (!dev)
        return Result<DevPtr>::fail({ ErrorCode::InternalError, "fido_dev_new failed" });

    int r = fido_dev_open(dev.get(), path.c_str());
    if (r != FIDO_OK)
        return Result<DevPtr>::fail(errorFromFido(r, "fido_dev_open"));

    if (timeoutMs > 0) {
        r = fido_dev_set_timeout(dev.get(), timeoutMs);
        if (r != FIDO_OK)
            return Result<DevPtr>::fail(errorFromFido(r, "fido_dev_set_timeout"));
    }

    return Result<DevPtr>::ok(std::move(dev));
}

void closeDevice(fido_dev_t* dev)
{
    if (dev)
        fido_dev_close(dev);
}

ByteVector copyBytes(const unsigned char* ptr, size_t len)
{
    if (!ptr || !len)
        return { };
    return ByteVector(ptr, ptr + len);
}

} // namespace

namespace linux_webauthn {

int assertionExtensionFlags(const WebAuthnGetRequest& request)
{
    return request.extensions.largeBlob ? FIDO_EXT_LARGEBLOB_KEY : 0;
}

int credentialExtensionFlags(const WebAuthnCreateRequest& request)
{
    return request.extensions.largeBlobSupport == LargeBlobSupport::None ? 0 : FIDO_EXT_LARGEBLOB_KEY;
}

std::string discoverFirstDevicePath()
{
    fido_init(0);

    constexpr size_t maxDevices = 64;
    fido_dev_info_t* infos = fido_dev_info_new(maxDevices);
    if (!infos)
        return { };

    size_t found = 0;
    int r = fido_dev_info_manifest(infos, maxDevices, &found);
    if (r != FIDO_OK || found == 0) {
        fido_dev_info_free(&infos, maxDevices);
        return { };
    }

    const fido_dev_info_t* info = fido_dev_info_ptr(infos, 0);
    const char* path = info ? fido_dev_info_path(info) : nullptr;
    std::string out = path ? path : "";
    fido_dev_info_free(&infos, maxDevices);
    return out;
}

} // namespace linux_webauthn

LinuxWebAuthnProvider::LinuxWebAuthnProvider(LinuxWebAuthnProviderOptions options)
    : m_options(std::move(options))
{
    fido_init(options.debug ? FIDO_DEBUG : 0);
}

bool LinuxWebAuthnProvider::isAvailable()
{
    return !linux_webauthn::discoverFirstDevicePath().empty();
}

Result<WebAuthnAssertion> LinuxWebAuthnProvider::getAssertion(const WebAuthnGetRequest& request)
{
    auto devResult = openDevice(m_options, static_cast<int>(std::min<std::chrono::milliseconds::rep>(request.timeout.count(), 0x7fffffff)));
    if (!devResult)
        return Result<WebAuthnAssertion>::fail(devResult.error());
    DevPtr dev = std::move(devResult.value());

    AssertPtr assertion(fido_assert_new());
    if (!assertion)
        return Result<WebAuthnAssertion>::fail({ ErrorCode::InternalError, "fido_assert_new failed" });

    const std::string clientDataJson = buildClientDataJson("webauthn.get", request.frame, request.challenge);
    auto clientData = reinterpret_cast<const unsigned char*>(clientDataJson.data());

    int r = fido_assert_set_clientdata(assertion.get(), clientData, clientDataJson.size());
    if (r != FIDO_OK)
        return failFido<WebAuthnAssertion>(r, "fido_assert_set_clientdata");
    r = fido_assert_set_rp(assertion.get(), request.relyingPartyId.c_str());
    if (r != FIDO_OK)
        return failFido<WebAuthnAssertion>(r, "fido_assert_set_rp");
    r = fido_assert_set_uv(assertion.get(), uvToFidoOpt(request.userVerification));
    if (r != FIDO_OK)
        return failFido<WebAuthnAssertion>(r, "fido_assert_set_uv");
    r = fido_assert_set_extensions(assertion.get(), linux_webauthn::assertionExtensionFlags(request));
    if (r != FIDO_OK)
        return failFido<WebAuthnAssertion>(r, "fido_assert_set_extensions");

    for (const auto& credential : request.allowCredentials) {
        if (credential.type != "public-key")
            continue;
        r = fido_assert_allow_cred(assertion.get(), credential.id.data(), credential.id.size());
        if (r != FIDO_OK)
            return failFido<WebAuthnAssertion>(r, "fido_assert_allow_cred");
    }

    r = fido_dev_get_assert(dev.get(), assertion.get(), m_options.pin.empty() ? nullptr : m_options.pin.c_str());
    if (r != FIDO_OK) {
        fido_dev_cancel(dev.get());
        closeDevice(dev.get());
        return failFido<WebAuthnAssertion>(r, "fido_dev_get_assert");
    }

    WebAuthnAssertion out;
    out.clientDataJSON.assign(clientDataJson.begin(), clientDataJson.end());
    out.credentialId = copyBytes(fido_assert_id_ptr(assertion.get(), 0), fido_assert_id_len(assertion.get(), 0));
    out.authenticatorData = copyBytes(fido_assert_authdata_ptr(assertion.get(), 0), fido_assert_authdata_len(assertion.get(), 0));
    out.signature = copyBytes(fido_assert_sig_ptr(assertion.get(), 0), fido_assert_sig_len(assertion.get(), 0));
    out.userHandle = copyBytes(fido_assert_user_id_ptr(assertion.get(), 0), fido_assert_user_id_len(assertion.get(), 0));
    out.largeBlobKey = copyBytes(fido_assert_largeblob_key_ptr(assertion.get(), 0), fido_assert_largeblob_key_len(assertion.get(), 0));

    if (request.extensions.largeBlob && !out.largeBlobKey.empty()) {
        if (request.extensions.largeBlob->read) {
            unsigned char* blob = nullptr;
            size_t blobLen = 0;
            r = fido_dev_largeblob_get(dev.get(), out.largeBlobKey.data(), out.largeBlobKey.size(), &blob, &blobLen);
            if (r != FIDO_OK) {
                closeDevice(dev.get());
                return failFido<WebAuthnAssertion>(r, "fido_dev_largeblob_get");
            }
            out.largeBlob = copyBytes(blob, blobLen);
            free(blob);
        } else if (!request.extensions.largeBlob->write.empty()) {
            const auto& blob = request.extensions.largeBlob->write;
            r = fido_dev_largeblob_set(dev.get(), out.largeBlobKey.data(), out.largeBlobKey.size(), blob.data(), blob.size(),
                m_options.pin.empty() ? nullptr : m_options.pin.c_str());
            if (r != FIDO_OK) {
                closeDevice(dev.get());
                return failFido<WebAuthnAssertion>(r, "fido_dev_largeblob_set");
            }
            out.largeBlobWritten = true;
        }
    }

    closeDevice(dev.get());
    return Result<WebAuthnAssertion>::ok(std::move(out));
}

Result<WebAuthnAttestation> LinuxWebAuthnProvider::makeCredential(const WebAuthnCreateRequest& request)
{
    auto devResult = openDevice(m_options, static_cast<int>(std::min<std::chrono::milliseconds::rep>(request.timeout.count(), 0x7fffffff)));
    if (!devResult)
        return Result<WebAuthnAttestation>::fail(devResult.error());
    DevPtr dev = std::move(devResult.value());

    CredPtr cred(fido_cred_new());
    if (!cred)
        return Result<WebAuthnAttestation>::fail({ ErrorCode::InternalError, "fido_cred_new failed" });

    const std::string clientDataJson = buildClientDataJson("webauthn.create", request.frame, request.challenge);
    auto clientData = reinterpret_cast<const unsigned char*>(clientDataJson.data());

    int r = fido_cred_set_clientdata(cred.get(), clientData, clientDataJson.size());
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_clientdata");
    r = fido_cred_set_rp(cred.get(), request.relyingPartyId.c_str(), request.relyingPartyName.c_str());
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_rp");
    r = fido_cred_set_user(cred.get(), request.userId.data(), request.userId.size(), request.userName.c_str(), request.userDisplayName.c_str(), nullptr);
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_user");
    r = fido_cred_set_type(cred.get(), coseAlgorithmForRequest(request));
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_type");
    r = fido_cred_set_rk(cred.get(), request.residentKey ? FIDO_OPT_TRUE : FIDO_OPT_OMIT);
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_rk");
    r = fido_cred_set_uv(cred.get(), uvToFidoOpt(request.userVerification));
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_uv");
    r = fido_cred_set_extensions(cred.get(), linux_webauthn::credentialExtensionFlags(request));
    if (r != FIDO_OK)
        return failFido<WebAuthnAttestation>(r, "fido_cred_set_extensions");

    for (const auto& credential : request.excludeCredentials) {
        if (credential.type != "public-key")
            continue;
        r = fido_cred_exclude(cred.get(), credential.id.data(), credential.id.size());
        if (r != FIDO_OK)
            return failFido<WebAuthnAttestation>(r, "fido_cred_exclude");
    }

    r = fido_dev_make_cred(dev.get(), cred.get(), m_options.pin.empty() ? nullptr : m_options.pin.c_str());
    if (r != FIDO_OK) {
        fido_dev_cancel(dev.get());
        closeDevice(dev.get());
        return failFido<WebAuthnAttestation>(r, "fido_dev_make_cred");
    }

    WebAuthnAttestation out;
    out.clientDataJSON.assign(clientDataJson.begin(), clientDataJson.end());
    out.credentialId = copyBytes(fido_cred_id_ptr(cred.get()), fido_cred_id_len(cred.get()));
    out.attestationObject = buildAttestationObject(cred.get());
    out.largeBlobKey = copyBytes(fido_cred_largeblob_key_ptr(cred.get()), fido_cred_largeblob_key_len(cred.get()));

    closeDevice(dev.get());
    return Result<WebAuthnAttestation>::ok(std::move(out));
}

} // namespace ng

#endif
