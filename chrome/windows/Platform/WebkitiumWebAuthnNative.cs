// P/Invoke wrapper around browser/webauthn/WebAuthnBridgeC.h.
// Wired-but-inactive: a real WebAuthnController is constructed but its
// PlatformWebAuthnProvider always rejects.  IsInitialized=true while
// counters stay at 0.

using System;
using System.Runtime.InteropServices;

namespace Webkitium.Platform;

internal sealed class WebkitiumWebAuthnNative : IDisposable
{
    [DllImport("webkitium_color", EntryPoint = "wk_webauthn_create_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkWebAuthnCreate();

    [DllImport("webkitium_color", EntryPoint = "wk_webauthn_destroy_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern void WkWebAuthnDestroy(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_webauthn_is_initialized_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkWebAuthnIsInitialized(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_webauthn_request_count_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkWebAuthnRequestCount(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_webauthn_rejection_count_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkWebAuthnRejectionCount(IntPtr handle);

    private IntPtr _handle;
    private bool _disposed;

    public WebkitiumWebAuthnNative()
    {
        _handle = WkWebAuthnCreate();
        if (_handle == IntPtr.Zero)
            throw new InvalidOperationException("wk_webauthn_create returned null");
    }

    public bool IsInitialized
    {
        get { ThrowIfDisposed(); return WkWebAuthnIsInitialized(_handle) != 0; }
    }

    public int RequestCount
    {
        get { ThrowIfDisposed(); return WkWebAuthnRequestCount(_handle); }
    }

    public int RejectionCount
    {
        get { ThrowIfDisposed(); return WkWebAuthnRejectionCount(_handle); }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        if (_handle != IntPtr.Zero) { WkWebAuthnDestroy(_handle); _handle = IntPtr.Zero; }
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(WebkitiumWebAuthnNative));
    }
}
