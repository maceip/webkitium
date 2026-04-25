// Process-wide holder for the wired-but-inactive controllers.
//
// Constructed once in App.OnLaunched, disposed when the App exits.
// Settings pages and future feature surfaces read from this; nothing
// invokes the controllers beyond their read accessors yet.

using System;

namespace Webkitium.Platform;

internal sealed class BrowserServices : IDisposable
{
    public WebkitiumExtensionsNative Extensions { get; }
    public WebkitiumSyncNative       Sync       { get; }
    public WebkitiumWebAuthnNative   WebAuthn   { get; }

    public BrowserServices()
    {
        Extensions = new WebkitiumExtensionsNative();
        Sync       = new WebkitiumSyncNative();
        WebAuthn   = new WebkitiumWebAuthnNative();
    }

    public void Dispose()
    {
        Extensions.Dispose();
        Sync.Dispose();
        WebAuthn.Dispose();
    }
}
