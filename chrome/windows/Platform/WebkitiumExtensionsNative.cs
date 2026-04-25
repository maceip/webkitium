// P/Invoke wrapper around browser/extensions/ExtensionBridgeC.h.
//
// Wired-but-inactive: a fresh handle owns an empty ExtensionRegistry,
// so Count returns 0 and Id/Name accessors return null until the
// shell installs manifests.

using System;
using System.Runtime.InteropServices;

namespace Webkitium.Platform;

internal sealed class WebkitiumExtensionsNative : IDisposable
{
    [DllImport("webkitium_color", EntryPoint = "wk_extensions_create_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkExtensionsCreate();

    [DllImport("webkitium_color", EntryPoint = "wk_extensions_destroy_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern void WkExtensionsDestroy(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_extensions_count_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkExtensionsCount(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_extensions_id_at_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkExtensionsIdAt(IntPtr handle, int index);

    [DllImport("webkitium_color", EntryPoint = "wk_extensions_name_at_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkExtensionsNameAt(IntPtr handle, int index);

    [DllImport("webkitium_color", EntryPoint = "wk_extensions_string_free_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern void WkExtensionsStringFree(IntPtr ptr);

    private IntPtr _handle;
    private bool _disposed;

    public WebkitiumExtensionsNative()
    {
        _handle = WkExtensionsCreate();
        if (_handle == IntPtr.Zero)
            throw new InvalidOperationException("wk_extensions_create returned null");
    }

    public int Count
    {
        get
        {
            ThrowIfDisposed();
            return WkExtensionsCount(_handle);
        }
    }

    public string? IdAt(int index)
    {
        ThrowIfDisposed();
        return TakeUtf8(WkExtensionsIdAt(_handle, index));
    }

    public string? NameAt(int index)
    {
        ThrowIfDisposed();
        return TakeUtf8(WkExtensionsNameAt(_handle, index));
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        if (_handle != IntPtr.Zero)
        {
            WkExtensionsDestroy(_handle);
            _handle = IntPtr.Zero;
        }
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(WebkitiumExtensionsNative));
    }

    private static string? TakeUtf8(IntPtr ptr)
    {
        if (ptr == IntPtr.Zero) return null;
        try { return Marshal.PtrToStringUTF8(ptr); }
        finally { WkExtensionsStringFree(ptr); }
    }
}
