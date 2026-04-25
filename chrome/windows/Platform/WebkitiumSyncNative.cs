// P/Invoke wrapper around browser/sync/SyncBridgeC.h.
// Wired-but-inactive: stub backend reports zeros.

using System;
using System.Runtime.InteropServices;

namespace Webkitium.Platform;

internal sealed class WebkitiumSyncNative : IDisposable
{
    [DllImport("webkitium_color", EntryPoint = "wk_sync_create_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkSyncCreate();

    [DllImport("webkitium_color", EntryPoint = "wk_sync_destroy_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern void WkSyncDestroy(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_sync_record_count_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int WkSyncRecordCount(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_sync_current_version_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern long WkSyncCurrentVersion(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_sync_store_birthday_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr WkSyncStoreBirthday(IntPtr handle);

    [DllImport("webkitium_color", EntryPoint = "wk_sync_string_free_export",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern void WkSyncStringFree(IntPtr ptr);

    private IntPtr _handle;
    private bool _disposed;

    public WebkitiumSyncNative()
    {
        _handle = WkSyncCreate();
        if (_handle == IntPtr.Zero)
            throw new InvalidOperationException("wk_sync_create returned null");
    }

    public int RecordCount
    {
        get { ThrowIfDisposed(); return WkSyncRecordCount(_handle); }
    }

    public long CurrentVersion
    {
        get { ThrowIfDisposed(); return WkSyncCurrentVersion(_handle); }
    }

    public string? StoreBirthday
    {
        get
        {
            ThrowIfDisposed();
            var ptr = WkSyncStoreBirthday(_handle);
            if (ptr == IntPtr.Zero) return null;
            try { return Marshal.PtrToStringUTF8(ptr); }
            finally { WkSyncStringFree(ptr); }
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        if (_handle != IntPtr.Zero) { WkSyncDestroy(_handle); _handle = IntPtr.Zero; }
    }

    private void ThrowIfDisposed()
    {
        if (_disposed) throw new ObjectDisposedException(nameof(WebkitiumSyncNative));
    }
}
