#ifdef _WIN32

#include "platform/windows/WindowsWebAuthnProvider.h"

#include <cstdio>

int main()
{
    const DWORD ver = ng::WindowsWebAuthnProvider::apiVersion();
    std::printf("WebAuthNGetApiVersionNumber: %lu\n", static_cast<unsigned long>(ver));

    if (ver == 0) {
        std::printf("WebAuthn not available on this machine (skip UV-PAA probe).\n");
        return 0;
    }

    auto uv = ng::WindowsWebAuthnProvider::isUserVerifyingPlatformAuthenticatorAvailable();
    if (!uv) {
        std::printf("WebAuthNIsUserVerifyingPlatformAuthenticatorAvailable failed: %s\n",
            uv.error().message.c_str());
        return 0;
    }

    std::printf("User-verifying platform authenticator available: %s\n",
        uv.value() ? "yes" : "no");
    return 0;
}

#else

int main()
{
    return 0;
}

#endif
