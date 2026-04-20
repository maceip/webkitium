#include "platform/windows/WindowsWebAuthnProvider.h"

#ifdef _WIN32

#include <algorithm>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include <winerror.h>
#include <webauthn.h>

#ifndef NTE_USER_CANCELLED
#define NTE_USER_CANCELLED ((HRESULT)0x80090036L)
#endif

namespace ng {
namespace {

std::wstring utf8ToWide(const std::string& utf8)
{
    if (utf8.empty())
        return { };

    for (DWORD flags : { DWORD(MB_ERR_INVALID_CHARS), DWORD(0) }) {
        int n = MultiByteToWideChar(CP_UTF8, flags, utf8.data(), static_cast<int>(utf8.size()), nullptr, 0);
        if (n <= 0)
            continue;

        std::wstring out(static_cast<size_t>(n), L'\0');
        if (MultiByteToWideChar(CP_UTF8, flags, utf8.data(), static_cast<int>(utf8.size()), out.data(), n) == n)
            return out;
    }
    return { };
}

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
        default:
            out += static_cast<char>(c);
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
    const std::string challengeB64 = base64UrlEncode(challenge);
    const std::string origin = frame.origin.serialize();

    std::ostringstream json;
    json << "{\"type\":\"" << clientDataType << "\",\"challenge\":\"" << challengeB64 << "\",\"origin\":\""
         << jsonEscape(origin) << '"';
    if (frame.includeCrossOriginClientDataMember())
        json << ",\"crossOrigin\":true";
    json << '}';
    return json.str();
}

DWORD mapUserVerification(UserVerificationRequirement uv)
{
    switch (uv) {
    case UserVerificationRequirement::Required:
        return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_REQUIRED;
    case UserVerificationRequirement::Preferred:
        return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_PREFERRED;
    case UserVerificationRequirement::Discouraged:
        return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_DISCOURAGED;
    }
    return WEBAUTHN_USER_VERIFICATION_REQUIREMENT_PREFERRED;
}

DWORD mapAuthenticatorAttachment(AuthenticatorAttachment attachment)
{
    switch (attachment) {
    case AuthenticatorAttachment::Platform:
        return WEBAUTHN_AUTHENTICATOR_ATTACHMENT_PLATFORM;
    case AuthenticatorAttachment::CrossPlatform:
        return WEBAUTHN_AUTHENTICATOR_ATTACHMENT_CROSS_PLATFORM;
    case AuthenticatorAttachment::Any:
        return WEBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY;
    }
    return WEBAUTHN_AUTHENTICATOR_ATTACHMENT_ANY;
}

DWORD mapAttestationConveyance(AttestationConveyancePreference preference)
{
    switch (preference) {
    case AttestationConveyancePreference::None:
        return WEBAUTHN_ATTESTATION_CONVEYANCE_PREFERENCE_NONE;
    case AttestationConveyancePreference::Indirect:
        return WEBAUTHN_ATTESTATION_CONVEYANCE_PREFERENCE_INDIRECT;
    case AttestationConveyancePreference::Direct:
        return WEBAUTHN_ATTESTATION_CONVEYANCE_PREFERENCE_DIRECT;
    }
    return WEBAUTHN_ATTESTATION_CONVEYANCE_PREFERENCE_NONE;
}

DWORD mapTransports(const std::vector<std::string>& transports)
{
    if (transports.empty())
        return 0;

    DWORD flags = 0;
    for (const auto& t : transports) {
        if (t == WEBAUTHN_CTAP_TRANSPORT_USB_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_USB;
        else if (t == WEBAUTHN_CTAP_TRANSPORT_NFC_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_NFC;
        else if (t == WEBAUTHN_CTAP_TRANSPORT_BLE_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_BLE;
        else if (t == WEBAUTHN_CTAP_TRANSPORT_INTERNAL_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_INTERNAL;
        else if (t == WEBAUTHN_CTAP_TRANSPORT_HYBRID_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_HYBRID;
        else if (t == WEBAUTHN_CTAP_TRANSPORT_SMART_CARD_STRING)
            flags |= WEBAUTHN_CTAP_TRANSPORT_SMART_CARD;
    }
    return flags;
}

ErrorCode classifyWebAuthnHr(HRESULT hr)
{
    if (hr == NTE_USER_CANCELLED)
        return ErrorCode::PermissionDenied;
    if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED))
        return ErrorCode::PermissionDenied;
    if (hr == HRESULT_FROM_WIN32(ERROR_OPERATION_ABORTED))
        return ErrorCode::PermissionDenied;
    if (hr == E_INVALIDARG)
        return ErrorCode::InvalidArgument;
    return ErrorCode::PlatformFailure;
}

Error errorFromHr(HRESULT hr, const char* apiCall)
{
    using WebAuthNGetErrorNameFn = PCWSTR(WINAPI*)(HRESULT);
    static WebAuthNGetErrorNameFn getErrorName = nullptr;
    static bool resolvedGetErrorName = false;
    if (!resolvedGetErrorName) {
        resolvedGetErrorName = true;
        HMODULE module = ::GetModuleHandleW(L"webauthn.dll");
        if (!module)
            module = ::LoadLibraryW(L"webauthn.dll");
        if (module) {
            getErrorName = reinterpret_cast<WebAuthNGetErrorNameFn>(
                ::GetProcAddress(module, "WebAuthNGetErrorName"));
        }
    }

    std::string message = apiCall;
    PCWSTR name = getErrorName ? getErrorName(hr) : nullptr;
    if (name && name[0]) {
        int n = WideCharToMultiByte(CP_UTF8, 0, name, -1, nullptr, 0, nullptr, nullptr);
        if (n > 1) {
            std::string narrow(static_cast<size_t>(n - 1), '\0');
            WideCharToMultiByte(CP_UTF8, 0, name, -1, narrow.data(), n, nullptr, nullptr);
            message += ": ";
            message += narrow;
        }
    } else {
        message += " (HRESULT 0x";
        char buf[16];
        snprintf(buf, sizeof(buf), "%08lX", static_cast<unsigned long>(hr));
        message += buf;
        message += ")";
    }
    return { classifyWebAuthnHr(hr), std::move(message) };
}

} // namespace

DWORD WindowsWebAuthnProvider::apiVersion()
{
    return WebAuthNGetApiVersionNumber();
}

Result<bool> WindowsWebAuthnProvider::isUserVerifyingPlatformAuthenticatorAvailable()
{
    BOOL available = FALSE;
    HRESULT hr = WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable(&available);
    if (FAILED(hr))
        return Result<bool>::fail(errorFromHr(hr, "WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable"));
    return Result<bool>::ok(available != FALSE);
}

WindowsWebAuthnProvider::WindowsWebAuthnProvider(HWND parentWindow, WindowsWebAuthnProviderOptions options)
    : m_parentWindow(parentWindow)
    , m_options(std::move(options))
{
}

Result<WebAuthnAssertion> WindowsWebAuthnProvider::getAssertion(const WebAuthnGetRequest& request)
{
    if (WindowsWebAuthnProvider::apiVersion() == 0) {
        return Result<WebAuthnAssertion>::fail(
            { ErrorCode::Unsupported, "WebAuthn is not available on this system" });
    }

    const std::wstring rpIdW = utf8ToWide(request.relyingPartyId);
    if (rpIdW.empty() && !request.relyingPartyId.empty())
        return Result<WebAuthnAssertion>::fail({ ErrorCode::InvalidArgument, "invalid relying party id encoding" });

    const std::string clientDataJsonUtf8 = buildClientDataJson("webauthn.get", request.frame, request.challenge);
    std::vector<uint8_t> clientDataBytes(clientDataJsonUtf8.begin(), clientDataJsonUtf8.end());

    WEBAUTHN_CLIENT_DATA clientData { };
    clientData.dwVersion = WEBAUTHN_CLIENT_DATA_CURRENT_VERSION;
    clientData.cbClientDataJSON = static_cast<DWORD>(clientDataBytes.size());
    clientData.pbClientDataJSON = clientDataBytes.data();
    clientData.pwszHashAlgId = WEBAUTHN_HASH_ALGORITHM_SHA_256;

    std::vector<WEBAUTHN_CREDENTIAL_EX> credExStorage;
    std::vector<PWEBAUTHN_CREDENTIAL_EX> credPtrs;
    WEBAUTHN_CREDENTIAL_LIST allowList { };

    if (!request.allowCredentials.empty()) {
        credExStorage.reserve(request.allowCredentials.size());
        credPtrs.reserve(request.allowCredentials.size());
        for (const auto& desc : request.allowCredentials) {
            if (desc.type != "public-key")
                continue;

            WEBAUTHN_CREDENTIAL_EX ex { };
            ex.dwVersion = WEBAUTHN_CREDENTIAL_EX_CURRENT_VERSION;
            ex.cbId = static_cast<DWORD>(desc.id.size());
            ex.pbId = const_cast<PBYTE>(desc.id.data());
            ex.pwszCredentialType = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY;
            ex.dwTransports = mapTransports(desc.transports);

            credExStorage.push_back(ex);
        }

        for (auto& ex : credExStorage)
            credPtrs.push_back(&ex);

        if (!credPtrs.empty()) {
            allowList.cCredentials = static_cast<DWORD>(credPtrs.size());
            allowList.ppCredentials = credPtrs.data();
        }
    }

    WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS options { };
    ZeroMemory(&options, sizeof(options));
    const bool inPrivate = m_options.inPrivateBrowser;
    options.dwVersion = inPrivate ? WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS_VERSION_6
                                  : WEBAUTHN_AUTHENTICATOR_GET_ASSERTION_OPTIONS_VERSION_4;
    options.dwTimeoutMilliseconds = static_cast<DWORD>(
        std::min<std::chrono::milliseconds::rep>(request.timeout.count(), 0x7FFFFFFF));
    options.dwAuthenticatorAttachment = mapAuthenticatorAttachment(request.attachment);
    options.dwUserVerificationRequirement = mapUserVerification(request.userVerification);
    options.dwFlags = 0;
    options.pwszU2fAppId = nullptr;
    options.pbU2fAppId = nullptr;
    options.pCancellationId = nullptr;
    options.pAllowCredentialList = credPtrs.empty() ? nullptr : &allowList;
    if (inPrivate)
        options.bBrowserInPrivateMode = TRUE;

    PWEBAUTHN_ASSERTION assertion = nullptr;
    HRESULT hr = WebAuthNAuthenticatorGetAssertion(
        m_parentWindow, rpIdW.c_str(), &clientData, &options, &assertion);

    if (FAILED(hr))
        return Result<WebAuthnAssertion>::fail(errorFromHr(hr, "WebAuthNAuthenticatorGetAssertion"));
    if (!assertion)
        return Result<WebAuthnAssertion>::fail(
            { ErrorCode::PlatformFailure, "WebAuthNAuthenticatorGetAssertion returned null assertion" });

    WebAuthnAssertion out { };
    if (assertion->Credential.cbId && assertion->Credential.pbId) {
        out.credentialId.assign(assertion->Credential.pbId,
            assertion->Credential.pbId + assertion->Credential.cbId);
    }
    if (assertion->cbAuthenticatorData && assertion->pbAuthenticatorData) {
        out.authenticatorData.assign(assertion->pbAuthenticatorData,
            assertion->pbAuthenticatorData + assertion->cbAuthenticatorData);
    }
    if (assertion->cbSignature && assertion->pbSignature) {
        out.signature.assign(assertion->pbSignature,
            assertion->pbSignature + assertion->cbSignature);
    }
    if (assertion->cbUserId && assertion->pbUserId) {
        out.userHandle.assign(assertion->pbUserId,
            assertion->pbUserId + assertion->cbUserId);
    }

    if (assertion->cbClientDataJSON && assertion->pbClientDataJSON) {
        out.clientDataJSON.assign(assertion->pbClientDataJSON,
            assertion->pbClientDataJSON + assertion->cbClientDataJSON);
    } else {
        out.clientDataJSON = std::move(clientDataBytes);
    }

    WebAuthNFreeAssertion(assertion);
    return Result<WebAuthnAssertion>::ok(std::move(out));
}

Result<WebAuthnAttestation> WindowsWebAuthnProvider::makeCredential(const WebAuthnCreateRequest& request)
{
    if (WindowsWebAuthnProvider::apiVersion() == 0) {
        return Result<WebAuthnAttestation>::fail(
            { ErrorCode::Unsupported, "WebAuthn is not available on this system" });
    }

    const std::wstring rpIdW = utf8ToWide(request.relyingPartyId);
    const std::wstring rpNameW = utf8ToWide(request.relyingPartyName);
    if ((rpIdW.empty() && !request.relyingPartyId.empty())
        || (rpNameW.empty() && !request.relyingPartyName.empty()))
        return Result<WebAuthnAttestation>::fail({ ErrorCode::InvalidArgument, "invalid RP string encoding" });

    const std::wstring userNameW = utf8ToWide(request.userName);
    const std::wstring userDisplayW = utf8ToWide(request.userDisplayName);

    WEBAUTHN_RP_ENTITY_INFORMATION rp { };
    rp.dwVersion = WEBAUTHN_RP_ENTITY_INFORMATION_CURRENT_VERSION;
    rp.pwszId = rpIdW.c_str();
    rp.pwszName = rpNameW.c_str();
    rp.pwszIcon = nullptr;

    WEBAUTHN_USER_ENTITY_INFORMATION user { };
    user.dwVersion = WEBAUTHN_USER_ENTITY_INFORMATION_CURRENT_VERSION;
    user.cbId = static_cast<DWORD>(request.userId.size());
    user.pbId = request.userId.empty() ? nullptr : const_cast<PBYTE>(request.userId.data());
    user.pwszName = userNameW.c_str();
    user.pwszIcon = nullptr;
    user.pwszDisplayName = userDisplayW.empty() ? nullptr : userDisplayW.c_str();

    const std::string clientDataJsonUtf8 = buildClientDataJson("webauthn.create", request.frame, request.challenge);
    std::vector<uint8_t> clientDataBytes(clientDataJsonUtf8.begin(), clientDataJsonUtf8.end());

    WEBAUTHN_CLIENT_DATA clientData { };
    clientData.dwVersion = WEBAUTHN_CLIENT_DATA_CURRENT_VERSION;
    clientData.cbClientDataJSON = static_cast<DWORD>(clientDataBytes.size());
    clientData.pbClientDataJSON = clientDataBytes.data();
    clientData.pwszHashAlgId = WEBAUTHN_HASH_ALGORITHM_SHA_256;

    std::vector<WEBAUTHN_COSE_CREDENTIAL_PARAMETER> coseStorage;
    coseStorage.reserve(request.pubKeyCredAlgorithms.size());
    for (int32_t alg : request.pubKeyCredAlgorithms) {
        WEBAUTHN_COSE_CREDENTIAL_PARAMETER param { };
        param.dwVersion = WEBAUTHN_COSE_CREDENTIAL_PARAMETER_CURRENT_VERSION;
        param.pwszCredentialType = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY;
        param.lAlg = static_cast<LONG>(alg);
        coseStorage.push_back(param);
    }

    WEBAUTHN_COSE_CREDENTIAL_PARAMETERS coseList { };
    coseList.cCredentialParameters = static_cast<DWORD>(coseStorage.size());
    coseList.pCredentialParameters = coseStorage.data();

    std::vector<WEBAUTHN_CREDENTIAL_EX> credExStorage;
    std::vector<PWEBAUTHN_CREDENTIAL_EX> credPtrs;
    WEBAUTHN_CREDENTIAL_LIST excludeList { };

    if (!request.excludeCredentials.empty()) {
        credExStorage.reserve(request.excludeCredentials.size());
        credPtrs.reserve(request.excludeCredentials.size());
        for (const auto& desc : request.excludeCredentials) {
            if (desc.type != "public-key")
                continue;

            WEBAUTHN_CREDENTIAL_EX ex { };
            ex.dwVersion = WEBAUTHN_CREDENTIAL_EX_CURRENT_VERSION;
            ex.cbId = static_cast<DWORD>(desc.id.size());
            ex.pbId = const_cast<PBYTE>(desc.id.data());
            ex.pwszCredentialType = WEBAUTHN_CREDENTIAL_TYPE_PUBLIC_KEY;
            ex.dwTransports = mapTransports(desc.transports);

            credExStorage.push_back(ex);
        }

        for (auto& ex : credExStorage)
            credPtrs.push_back(&ex);

        if (!credPtrs.empty()) {
            excludeList.cCredentials = static_cast<DWORD>(credPtrs.size());
            excludeList.ppCredentials = credPtrs.data();
        }
    }

    WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS options { };
    ZeroMemory(&options, sizeof(options));
    const bool inPrivate = m_options.inPrivateBrowser;
    options.dwVersion = inPrivate ? WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS_VERSION_5
                                    : WEBAUTHN_AUTHENTICATOR_MAKE_CREDENTIAL_OPTIONS_VERSION_4;
    options.dwTimeoutMilliseconds = static_cast<DWORD>(
        std::min<std::chrono::milliseconds::rep>(request.timeout.count(), 0x7FFFFFFF));
    options.dwAuthenticatorAttachment = mapAuthenticatorAttachment(request.attachment);
    options.bRequireResidentKey = request.residentKey ? TRUE : FALSE;
    options.dwUserVerificationRequirement = mapUserVerification(request.userVerification);
    options.dwAttestationConveyancePreference = mapAttestationConveyance(request.attestation);
    options.dwFlags = 0;
    options.pCancellationId = nullptr;
    options.pExcludeCredentialList = credPtrs.empty() ? nullptr : &excludeList;
    options.dwEnterpriseAttestation = WEBAUTHN_ENTERPRISE_ATTESTATION_NONE;
    options.dwLargeBlobSupport = WEBAUTHN_LARGE_BLOB_SUPPORT_NONE;
    options.bPreferResidentKey = FALSE;
    if (inPrivate)
        options.bBrowserInPrivateMode = TRUE;

    PWEBAUTHN_CREDENTIAL_ATTESTATION attestation = nullptr;
    HRESULT hr = WebAuthNAuthenticatorMakeCredential(
        m_parentWindow, &rp, &user, &coseList, &clientData, &options, &attestation);

    if (FAILED(hr))
        return Result<WebAuthnAttestation>::fail(errorFromHr(hr, "WebAuthNAuthenticatorMakeCredential"));
    if (!attestation)
        return Result<WebAuthnAttestation>::fail(
            { ErrorCode::PlatformFailure, "WebAuthNAuthenticatorMakeCredential returned null attestation" });

    WebAuthnAttestation out { };
    if (attestation->cbCredentialId && attestation->pbCredentialId) {
        out.credentialId.assign(attestation->pbCredentialId,
            attestation->pbCredentialId + attestation->cbCredentialId);
    }
    if (attestation->cbAttestationObject && attestation->pbAttestationObject) {
        out.attestationObject.assign(attestation->pbAttestationObject,
            attestation->pbAttestationObject + attestation->cbAttestationObject);
    }
    if (attestation->cbClientDataJSON && attestation->pbClientDataJSON) {
        out.clientDataJSON.assign(attestation->pbClientDataJSON,
            attestation->pbClientDataJSON + attestation->cbClientDataJSON);
    } else {
        out.clientDataJSON = std::move(clientDataBytes);
    }

    WebAuthNFreeCredentialAttestation(attestation);
    return Result<WebAuthnAttestation>::ok(std::move(out));
}

} // namespace ng

#endif
