#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>
#import <AuthenticationServices/AuthenticationServices.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "platform/macos/MacOSWebAuthnProvider.h"

#include <dispatch/dispatch.h>

namespace ng {
namespace {

NSString* NSStringFromUtf8(const std::string& s)
{
    return [[NSString alloc] initWithBytes:s.data()
                                    length:s.size()
                                  encoding:NSUTF8StringEncoding];
}

void AppendBytesFromNSData(ByteVector& out, NSData* data)
{
    if (data.length == 0)
        return;
    const auto* p = static_cast<const uint8_t*>(data.bytes);
    out.assign(p, p + data.length);
}

NSData* NSDataFromByteVector(const ByteVector& v)
{
    if (v.empty())
        return [NSData data];
    return [NSData dataWithBytes:v.data() length:v.size()];
}

ASPublicKeyCredentialUserVerificationPreference nsUserVerification(UserVerificationRequirement uv)
{
    switch (uv) {
    case UserVerificationRequirement::Required:
        return ASPublicKeyCredentialUserVerificationPreferenceRequired;
    case UserVerificationRequirement::Preferred:
        return ASPublicKeyCredentialUserVerificationPreferencePreferred;
    case UserVerificationRequirement::Discouraged:
        return ASPublicKeyCredentialUserVerificationPreferenceDiscouraged;
    }
    return ASPublicKeyCredentialUserVerificationPreferencePreferred;
}

ASPublicKeyCredentialAttestationKind nsAttestation(AttestationConveyancePreference p)
{
    switch (p) {
    case AttestationConveyancePreference::None:
        return ASPublicKeyCredentialAttestationKindNone;
    case AttestationConveyancePreference::Indirect:
        return ASPublicKeyCredentialAttestationKindIndirect;
    case AttestationConveyancePreference::Direct:
        return ASPublicKeyCredentialAttestationKindDirect;
    }
    return ASPublicKeyCredentialAttestationKindNone;
}

ASPublicKeyCredentialResidentKeyPreference nsResidentKey(bool resident)
{
    return resident ? ASPublicKeyCredentialResidentKeyPreferenceRequired
                    : ASPublicKeyCredentialResidentKeyPreferenceDiscouraged;
}

NSArray<NSNumber*>* NsTransportNumbers(const std::vector<std::string>& transports)
{
    NSMutableArray* a = [NSMutableArray array];
    for (const auto& t : transports) {
        ASPublicKeyCredentialTransport tr = ASPublicKeyCredentialTransportUSB;
        if (t == "usb" || t == "hybrid" || t == "smart-card")
            tr = ASPublicKeyCredentialTransportUSB;
        else if (t == "nfc")
            tr = ASPublicKeyCredentialTransportNFC;
        else if (t == "ble")
            tr = ASPublicKeyCredentialTransportBluetoothLE;
        else if (t == "internal")
            tr = ASPublicKeyCredentialTransportInternal;
        else
            continue;
        [a addObject:@(tr)];
    }
    return a;
}

NSArray<ASAuthorizationPublicKeyCredentialParameters*>* BuildSecurityKeyCredentialParameters(
    const std::vector<int32_t>& algorithms)
{
    NSMutableArray* params = [NSMutableArray arrayWithCapacity:algorithms.size()];
    for (int32_t cose : algorithms) {
        ASAuthorizationPublicKeyCredentialParameters* p =
            [[ASAuthorizationPublicKeyCredentialParameters alloc] initWithAlgorithm:static_cast<NSInteger>(cose)];
        if (p)
            [params addObject:p];
    }
    return params;
}

Error errorFromNsError(NSError* error)
{
    if (!error)
        return { ErrorCode::PlatformFailure, "unknown AuthenticationServices error" };

    if ([error.domain isEqualToString:ASAuthorizationErrorDomain]) {
        if (error.code == ASAuthorizationErrorCanceled) {
            return { ErrorCode::PermissionDenied, "passkey authorization canceled" };
        }
    }

    std::string msg;
    if (error.localizedDescription) {
        const char* utf8 = error.localizedDescription.UTF8String;
        if (utf8)
            msg = utf8;
    }
    if (msg.empty())
        msg = "AuthenticationServices error";
    return { ErrorCode::PlatformFailure, std::move(msg) };
}

@interface NgWebAuthnAuthorizationSession : NSObject <ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding>
@property(nonatomic, assign) ASPresentationAnchor presentationAnchor;
@property(nonatomic, copy) void (^completion)(ASAuthorization* _Nullable authorization, NSError* _Nullable error);
@end

@implementation NgWebAuthnAuthorizationSession

- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController*)controller
{
    (void)controller;
    return self.presentationAnchor;
}

- (void)authorizationController:(ASAuthorizationController*)controller
    didCompleteWithAuthorization:(ASAuthorization*)authorization
{
    (void)controller;
    if (self.completion)
        self.completion(authorization, nil);
}

- (void)authorizationController:(ASAuthorizationController*)controller didCompleteWithError:(NSError*)error
{
    (void)controller;
    if (self.completion)
        self.completion(nil, error);
}

@end

static ASPresentationAnchor ResolvePresentationAnchor(void* presentationWindow)
{
    NSWindow* explicitWin = (__bridge NSWindow*)presentationWindow;
    if (explicitWin)
        return explicitWin;
    NSWindow* key = [NSApp keyWindow];
    if (key)
        return key;
    NSWindow* main = [NSApp mainWindow];
    if (main)
        return main;
    return nil;
}

template<typename Completion>
static void RunAuthorizationOnMain(NSArray<ASAuthorizationRequest*>* requests, void* presentationWindow,
    Completion completion)
{
    NgWebAuthnAuthorizationSession* session = [NgWebAuthnAuthorizationSession new];
    session.presentationAnchor = ResolvePresentationAnchor(presentationWindow);

    ASAuthorizationController* controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:requests];
    controller.delegate = session;
    controller.presentationContextProvider = session;

    static char kAssocKey;
    objc_setAssociatedObject(controller, &kAssocKey, session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    session.completion = ^(ASAuthorization* authorization, NSError* error) {
        objc_setAssociatedObject(controller, &kAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        completion(authorization, error);
    };

    [controller performRequests];
}

void FillAssertionFromPublicKeyCredential(WebAuthnAssertion& out, ASPublicKeyCredential* common,
    NSData* authenticatorData, NSData* signature)
{
    AppendBytesFromNSData(out.credentialId, common.credentialID);
    AppendBytesFromNSData(out.authenticatorData, authenticatorData);
    AppendBytesFromNSData(out.clientDataJSON, common.rawClientDataJSON);
    AppendBytesFromNSData(out.signature, signature);
    AppendBytesFromNSData(out.userHandle, common.userID);
}

Result<WebAuthnAssertion> ParseAssertionAuthorization(ASAuthorization* authorization)
{
    id rawCred = authorization.credential;
    if ([rawCred isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialAssertion class]]) {
        auto* cred = static_cast<ASAuthorizationPlatformPublicKeyCredentialAssertion*>(rawCred);
        WebAuthnAssertion out;
        FillAssertionFromPublicKeyCredential(out, cred, cred.rawAuthenticatorData, cred.signature);
        return Result<WebAuthnAssertion>::ok(std::move(out));
    }
    if ([rawCred isKindOfClass:[ASAuthorizationSecurityKeyPublicKeyCredentialAssertion class]]) {
        auto* cred = static_cast<ASAuthorizationSecurityKeyPublicKeyCredentialAssertion*>(rawCred);
        WebAuthnAssertion out;
        FillAssertionFromPublicKeyCredential(out, cred, cred.rawAuthenticatorData, cred.signature);
        return Result<WebAuthnAssertion>::ok(std::move(out));
    }
    return Result<WebAuthnAssertion>::fail(
        { ErrorCode::PlatformFailure, "unexpected credential type from AuthenticationServices" });
}

void FillRegistrationFromPublicKeyCredential(WebAuthnAttestation& out, ASPublicKeyCredential* common,
    NSData* attestationObject)
{
    AppendBytesFromNSData(out.credentialId, common.credentialID);
    AppendBytesFromNSData(out.clientDataJSON, common.rawClientDataJSON);
    AppendBytesFromNSData(out.attestationObject, attestationObject);
}

Result<WebAuthnAttestation> ParseRegistrationAuthorization(ASAuthorization* authorization)
{
    id rawCred = authorization.credential;
    if ([rawCred isKindOfClass:[ASAuthorizationPlatformPublicKeyCredentialRegistration class]]) {
        auto* cred = static_cast<ASAuthorizationPlatformPublicKeyCredentialRegistration*>(rawCred);
        WebAuthnAttestation out;
        FillRegistrationFromPublicKeyCredential(out, cred, cred.rawAttestationObject);
        return Result<WebAuthnAttestation>::ok(std::move(out));
    }
    if ([rawCred isKindOfClass:[ASAuthorizationSecurityKeyPublicKeyCredentialRegistration class]]) {
        auto* cred = static_cast<ASAuthorizationSecurityKeyPublicKeyCredentialRegistration*>(rawCred);
        WebAuthnAttestation out;
        FillRegistrationFromPublicKeyCredential(out, cred, cred.rawAttestationObject);
        return Result<WebAuthnAttestation>::ok(std::move(out));
    }
    return Result<WebAuthnAttestation>::fail(
        { ErrorCode::PlatformFailure, "unexpected credential type from AuthenticationServices" });
}

} // namespace

MacOSWebAuthnProvider::MacOSWebAuthnProvider(void* presentationWindow)
    : m_presentationWindow(presentationWindow)
{
}

Result<WebAuthnAssertion> MacOSWebAuthnProvider::getAssertion(const WebAuthnGetRequest& request)
{
    if ([NSThread isMainThread]) {
        return Result<WebAuthnAssertion>::fail(
            { ErrorCode::InvalidArgument,
                "MacOSWebAuthnProvider::getAssertion must be called off the main thread" });
    }

    if (@available(macOS 13.0, *)) { } else {
        return Result<WebAuthnAssertion>::fail(
            { ErrorCode::Unsupported, "macOS 13+ required for AuthenticationServices WebAuthn" });
    }

    NSString* rpId = NSStringFromUtf8(request.relyingPartyId);
    NSData* challenge = NSDataFromByteVector(request.challenge);
    if (!rpId.length || !challenge.length) {
        return Result<WebAuthnAssertion>::fail({ ErrorCode::InvalidArgument, "rpId and challenge required" });
    }

    const bool wantPlatform = request.attachment == AuthenticatorAttachment::Platform
        || request.attachment == AuthenticatorAttachment::Any;
    const bool wantSecurityKey = request.attachment == AuthenticatorAttachment::CrossPlatform
        || request.attachment == AuthenticatorAttachment::Any;

    __block Result<WebAuthnAssertion> outResult = Result<WebAuthnAssertion>::fail({ ErrorCode::InternalError, "" });
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray<ASAuthorizationRequest*>* reqs = [NSMutableArray array];

        if (wantPlatform) {
            ASAuthorizationPlatformPublicKeyCredentialProvider* plat =
                [[ASAuthorizationPlatformPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:rpId];
            ASAuthorizationPlatformPublicKeyCredentialAssertionRequest* asReq =
                [plat createCredentialAssertionRequestWithChallenge:challenge];
            asReq.userVerificationPreference = nsUserVerification(request.userVerification);
            if (!request.allowCredentials.empty()) {
                NSMutableArray* allowed = [NSMutableArray array];
                for (const auto& desc : request.allowCredentials) {
                    if (desc.type != "public-key")
                        continue;
                    NSData* cid = NSDataFromByteVector(desc.id);
                    if (!cid.length)
                        continue;
                    ASAuthorizationPlatformPublicKeyCredentialDescriptor* d =
                        [[ASAuthorizationPlatformPublicKeyCredentialDescriptor alloc] initWithCredentialID:cid];
                    [allowed addObject:d];
                }
                if (allowed.count)
                    asReq.allowedCredentials = allowed;
            }
            [reqs addObject:asReq];
        }

        if (wantSecurityKey) {
            ASAuthorizationSecurityKeyPublicKeyCredentialProvider* skp =
                [[ASAuthorizationSecurityKeyPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:rpId];
            ASAuthorizationSecurityKeyPublicKeyCredentialAssertionRequest* skReq =
                [skp createCredentialAssertionRequestWithChallenge:challenge];
            skReq.userVerificationPreference = nsUserVerification(request.userVerification);
            if (!request.allowCredentials.empty()) {
                NSMutableArray* allowed = [NSMutableArray array];
                for (const auto& desc : request.allowCredentials) {
                    if (desc.type != "public-key")
                        continue;
                    NSData* cid = NSDataFromByteVector(desc.id);
                    if (!cid.length)
                        continue;
                    NSArray* tr = NsTransportNumbers(desc.transports);
                    ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor* d =
                        [[ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor alloc] initWithCredentialID:cid
                                                                                                  transports:tr];
                    [allowed addObject:d];
                }
                if (allowed.count)
                    skReq.allowedCredentials = allowed;
            }
            [reqs addObject:skReq];
        }

        if (reqs.count == 0) {
            outResult = Result<WebAuthnAssertion>::fail(
                { ErrorCode::InvalidArgument, "no WebAuthn requests (check AuthenticatorAttachment)" });
            dispatch_semaphore_signal(sem);
            return;
        }

        RunAuthorizationOnMain(reqs, m_presentationWindow, ^(ASAuthorization* authorization, NSError* error) {
            if (error)
                outResult = Result<WebAuthnAssertion>::fail(errorFromNsError(error));
            else if (!authorization)
                outResult = Result<WebAuthnAssertion>::fail({ ErrorCode::PlatformFailure, "nil authorization" });
            else
                outResult = ParseAssertionAuthorization(authorization);
            dispatch_semaphore_signal(sem);
        });
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return outResult;
}

Result<WebAuthnAttestation> MacOSWebAuthnProvider::makeCredential(const WebAuthnCreateRequest& request)
{
    if ([NSThread isMainThread]) {
        return Result<WebAuthnAttestation>::fail(
            { ErrorCode::InvalidArgument,
                "MacOSWebAuthnProvider::makeCredential must be called off the main thread" });
    }

    if (@available(macOS 13.0, *)) { } else {
        return Result<WebAuthnAttestation>::fail(
            { ErrorCode::Unsupported, "macOS 13+ required for AuthenticationServices WebAuthn" });
    }

    NSString* rpId = NSStringFromUtf8(request.relyingPartyId);
    NSData* challenge = NSDataFromByteVector(request.challenge);
    NSData* userId = NSDataFromByteVector(request.userId);
    NSString* name = NSStringFromUtf8(request.userName);
    NSString* display = NSStringFromUtf8(request.userDisplayName);

    if (!rpId.length || !challenge.length) {
        return Result<WebAuthnAttestation>::fail({ ErrorCode::InvalidArgument, "rpId and challenge required" });
    }

    const bool wantPlatform = request.attachment == AuthenticatorAttachment::Platform
        || request.attachment == AuthenticatorAttachment::Any;
    const bool wantSecurityKey = request.attachment == AuthenticatorAttachment::CrossPlatform
        || request.attachment == AuthenticatorAttachment::Any;

    __block Result<WebAuthnAttestation> outResult = Result<WebAuthnAttestation>::fail({ ErrorCode::InternalError, "" });
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSMutableArray<ASAuthorizationRequest*>* reqs = [NSMutableArray array];

        if (wantPlatform) {
            ASAuthorizationPlatformPublicKeyCredentialProvider* plat =
                [[ASAuthorizationPlatformPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:rpId];
            ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest* regReq =
                [plat createCredentialRegistrationRequestWithChallenge:challenge
                                                                    name:name
                                                                  userID:userId
                                                       userDisplayName:display];
            regReq.userVerificationPreference = nsUserVerification(request.userVerification);
            regReq.attestationPreference = nsAttestation(request.attestation);
            regReq.residentKeyPreference = nsResidentKey(request.residentKey);
            if (!request.pubKeyCredAlgorithms.empty()) {
                NSMutableArray* algs = [NSMutableArray arrayWithCapacity:request.pubKeyCredAlgorithms.size()];
                for (int32_t cose : request.pubKeyCredAlgorithms)
                    [algs addObject:@(cose)];
                regReq.supportedAlgorithms = algs;
            }
            [reqs addObject:regReq];
        }

        if (wantSecurityKey) {
            ASAuthorizationSecurityKeyPublicKeyCredentialProvider* skp =
                [[ASAuthorizationSecurityKeyPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:rpId];
            ASAuthorizationSecurityKeyPublicKeyCredentialRegistrationRequest* skReg =
                [skp createCredentialRegistrationRequestWithChallenge:challenge
                                                        displayName:display
                                                               name:name
                                                             userID:userId];
            skReg.userVerificationPreference = nsUserVerification(request.userVerification);
            skReg.attestationPreference = nsAttestation(request.attestation);
            skReg.residentKeyPreference = nsResidentKey(request.residentKey);
            if (!request.pubKeyCredAlgorithms.empty())
                skReg.credentialParameters = BuildSecurityKeyCredentialParameters(request.pubKeyCredAlgorithms);

            if (!request.excludeCredentials.empty()) {
                NSMutableArray* excluded = [NSMutableArray array];
                for (const auto& desc : request.excludeCredentials) {
                    if (desc.type != "public-key")
                        continue;
                    NSData* cid = NSDataFromByteVector(desc.id);
                    if (!cid.length)
                        continue;
                    NSArray* tr = NsTransportNumbers(desc.transports);
                    ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor* d =
                        [[ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor alloc] initWithCredentialID:cid
                                                                                                    transports:tr];
                    [excluded addObject:d];
                }
                if (excluded.count)
                    skReg.excludedCredentials = excluded;
            }
            [reqs addObject:skReg];
        }

        if (reqs.count == 0) {
            outResult = Result<WebAuthnAttestation>::fail(
                { ErrorCode::InvalidArgument, "no WebAuthn requests (check AuthenticatorAttachment)" });
            dispatch_semaphore_signal(sem);
            return;
        }

        RunAuthorizationOnMain(reqs, m_presentationWindow, ^(ASAuthorization* authorization, NSError* error) {
            if (error)
                outResult = Result<WebAuthnAttestation>::fail(errorFromNsError(error));
            else if (!authorization)
                outResult = Result<WebAuthnAttestation>::fail({ ErrorCode::PlatformFailure, "nil authorization" });
            else
                outResult = ParseRegistrationAuthorization(authorization);
            dispatch_semaphore_signal(sem);
        });
    });

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return outResult;
}

} // namespace ng

#endif // TARGET_OS_OSX
