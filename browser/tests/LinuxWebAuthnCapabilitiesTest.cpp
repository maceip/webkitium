#include "platform/linux/LinuxWebAuthnProvider.h"

#include <cassert>

int main()
{
    ng::WebAuthnGetRequest get;
    assert(ng::linux_webauthn::assertionExtensionFlags(get) == 0);

    get.extensions.largeBlob = ng::WebAuthnLargeBlobAuthenticationInput { true, { } };
    assert(ng::linux_webauthn::assertionExtensionFlags(get) != 0);

    ng::WebAuthnCreateRequest create;
    assert(ng::linux_webauthn::credentialExtensionFlags(create) == 0);

    create.extensions.largeBlobSupport = ng::LargeBlobSupport::Preferred;
    assert(ng::linux_webauthn::credentialExtensionFlags(create) != 0);

    ng::LinuxWebAuthnProvider::isAvailable();
    ng::linux_webauthn::discoverFirstDevicePath();
    return 0;
}
