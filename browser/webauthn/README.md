# WebAuthn And Passkeys

`WebAuthnController` is the portable ceremony controller. It validates request
shape, trustworthy origin, user activation, challenge length, timeout, and
relying party identity before calling the platform authenticator provider.

Platform providers own native authenticator calls only:

- Windows: Windows WebAuthn API / Windows Hello
- Android: Credential Manager via `platform/android/AndroidWebAuthnProvider`
- macOS: `platform/macos/MacOSWebAuthnProvider` (AuthenticationServices platform passkeys; call off the main thread)
- iOS: AuthenticationServices (not wired in this tree yet)
- Linux: libfido2 or a future platform credential provider

The controller is deliberately narrow. UI may gather consent and present account
choices, but request policy stays in the portable controller.

---
