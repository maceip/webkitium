using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Webkitium.FFI;

/// <summary>
/// cdecl exports from webkitium_host.dll — WKView embedding for WebKit-for-Windows.
/// </summary>
internal static partial class WebKitHostBridge
{
    private const string DllName = "webkitium_host.dll";

    [LibraryImport(DllName, EntryPoint = "wk_host_initialize")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial int Initialize();

    [LibraryImport(DllName, EntryPoint = "wk_host_view_create")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial nint ViewCreate(nint parentHwnd, int x, int y, int width, int height);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_destroy")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewDestroy(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_set_frame")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewSetFrame(nint view, int x, int y, int width, int height);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_set_visible")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewSetVisible(nint view, int visible);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_load_url")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewLoadUrl(nint view, [MarshalAs(UnmanagedType.LPUTF8Str)] string utf8Url);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_go_back")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewGoBack(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_go_forward")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewGoForward(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_reload")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial void ViewReload(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_can_go_back")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial int ViewCanGoBack(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_can_go_forward")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial int ViewCanGoForward(nint view);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_copy_url")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial nuint ViewCopyUrl(nint view, byte[] buf, nuint bufLen);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_copy_title")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial nuint ViewCopyTitle(nint view, byte[] buf, nuint bufLen);

    [LibraryImport(DllName, EntryPoint = "wk_host_view_run_script")]
    [UnmanagedCallConv(CallConvs = [typeof(System.Runtime.CompilerServices.CallConvCdecl)])]
    internal static partial nuint ViewRunScript(nint view, [MarshalAs(UnmanagedType.LPUTF8Str)] string script, byte[] outBuf, nuint outLen, uint timeoutMs);

    internal static string CopyUtf8(nint view, ViewStringCopier copier)
    {
        var buf = new byte[4096];
        var needed = copier(view, buf, (nuint)buf.Length);
        if (needed == 0)
            return string.Empty;
        if (needed >= (nuint)buf.Length)
        {
            buf = new byte[(int)needed];
            copier(view, buf, (nuint)buf.Length);
        }
        var len = Array.IndexOf(buf, (byte)0);
        if (len < 0) len = buf.Length;
        return System.Text.Encoding.UTF8.GetString(buf, 0, len);
    }

    internal delegate nuint ViewStringCopier(nint view, byte[] buf, nuint bufLen);
}
