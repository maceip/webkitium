# Platform Adapters

Platform code implements these interfaces:

- Windows: Win32/WebView host, Windows WebAuthn API or Windows Hello, WebKit
  Windows script-message bridge, Dawn/WebGPU process integration.
- Android: WPE Android UI, Android Credential Manager/FIDO2 provider,
  WebKitUserContentManager bridge, Android storage and lifecycle.
- macOS: AppKit shell, `MacOSWebAuthnProvider` (AuthenticationServices), Keychain-backed storage (planned).
- iOS: UIKit shell, AuthenticationServices/LocalAuthentication (planned).
- Linux: GTK/WPE UI, `LinuxWebAuthnProvider` (libfido2 security-key/CTAP
  provider) or a future D-Bus portal provider, WPE/GTK message handlers.

The portable core must not include platform headers. If a feature cannot be
implemented without a platform include, add a method here and implement it in the
platform layer.

## Android WebAuthn Provider

`platform/android/WebAuthnCredentialManagerJson.cpp` builds the JSON strings
expected by AndroidX Credential Manager (`GetPublicKeyCredentialOption` and
`CreatePublicKeyCredentialRequest`). `AndroidWebAuthnProvider` wraps that output
in `AndroidWebAuthnAssertionRequest` and `AndroidWebAuthnCreationRequest` and
forwards to `AndroidWebAuthnBridge`. The bridge is the JNI/Kotlin boundary: it
should call `CredentialManager.getCredential(...)` with
`GetCredentialRequest(listOf(GetPublicKeyCredentialOption(requestJson, null)))`
for assertions, and `CredentialManager.createCredential(...)` with
`CreatePublicKeyCredentialRequest(requestJson)` for registration, then return
decoded WebAuthn fields to C++.

Android app-specific identity is carried in `AndroidAppInfo`. Its origin follows
the Android identity sample contract:

```text
android:apk-key-hash:<base64url(SHA-256 signing cert)>
```

The Kotlin side should provide the package name and SHA-256 signing certificate
hash for the app hosting WebAuthn. This mirrors the Android sample's
`appInfoToOrigin(CallingAppInfo)` helper and keeps native C++ free of Android
framework headers.

## Linux WebAuthn Provider

`platform/linux/LinuxWebAuthnProvider` uses Yubico `libfido2`, matching the
common Linux desktop security-key path used by FIDO2 tooling. It discovers the
first available FIDO device unless a `LinuxWebAuthnProviderOptions::devicePath`
is supplied. PIN collection is still caller-owned and is passed through
`LinuxWebAuthnProviderOptions::pin`.

The provider requests `FIDO_EXT_LARGEBLOB_KEY` when WebAuthn largeBlob support
is requested. On assertions, it uses the returned credential-bound key with
`fido_dev_largeblob_get` or `fido_dev_largeblob_set` for largeBlob read/write.

---
