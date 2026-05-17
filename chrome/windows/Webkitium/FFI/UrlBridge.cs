// P/Invoke wrappers for browser/url/UrlBridgeC.h.
//
// Lifetime: every returned char* is malloc'd inside webkitium_core.dll
// and MUST be freed with wk_url_free. The C# wrappers own that lifecycle
// — callers see plain `string` results.

using System;
using System.Runtime.InteropServices;

namespace Webkitium.FFI;

public enum NormalizeKind
{
    Url = 0,
    Search = 1,
}

public static partial class UrlBridge
{
    private const string Dll = "webkitium_core";

    // int wk_url_normalize(const char* raw_input, const char* engine_id, char** out_url);
    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
    private static partial int wk_url_normalize(string raw_input, string engine_id, out IntPtr out_url);

    // void wk_url_free(char* p);
    [LibraryImport(Dll)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
    private static partial void wk_url_free(IntPtr p);

    // char* wk_url_scrub_tracking(const char* url);
    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
    private static partial IntPtr wk_url_scrub_tracking(string url);

    // char* wk_search_engine_search_url(const char* engine_id, const char* query);
    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
    private static partial IntPtr wk_search_engine_search_url(string engine_id, string query);

    // char* wk_search_engine_suggest_url(const char* engine_id, const char* query);
    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(System.Runtime.CompilerServices.CallConvCdecl) })]
    private static partial IntPtr wk_search_engine_suggest_url(string engine_id, string query);

    /// <summary>
    /// Normalize a URL-bar input. Returns (Kind, NavigableUrl) where Url means
    /// the input was a URL (possibly with https:// prepended), and Search means
    /// the input became a search-engine query URL.
    /// </summary>
    /// <exception cref="ArgumentException">Input was empty or otherwise invalid.</exception>
    public static (NormalizeKind Kind, string Url) Normalize(string raw, string engineId)
    {
        int kind = wk_url_normalize(raw, engineId, out IntPtr outPtr);
        if (kind < 0 || outPtr == IntPtr.Zero)
        {
            throw new ArgumentException($"wk_url_normalize rejected input '{raw}'", nameof(raw));
        }
        try
        {
            string? s = Marshal.PtrToStringUTF8(outPtr);
            if (s is null) throw new InvalidOperationException("wk_url_normalize returned a null string body");
            return ((NormalizeKind)kind, s);
        }
        finally
        {
            wk_url_free(outPtr);
        }
    }

    /// <summary>
    /// Strip tracking params. Returns null when the C side rejects the input
    /// (NULL / unparseable). On success, returns a fresh string semantically
    /// equal to <paramref name="url"/> if no trackers were present.
    /// </summary>
    public static string? ScrubTracking(string url)
    {
        IntPtr p = wk_url_scrub_tracking(url);
        return p == IntPtr.Zero ? null : MarshalAndFree(p);
    }

    public static string? SearchUrl(string engineId, string query)
    {
        IntPtr p = wk_search_engine_search_url(engineId, query);
        return p == IntPtr.Zero ? null : MarshalAndFree(p);
    }

    public static string? SuggestUrl(string engineId, string query)
    {
        IntPtr p = wk_search_engine_suggest_url(engineId, query);
        return p == IntPtr.Zero ? null : MarshalAndFree(p);
    }

    private static string? MarshalAndFree(IntPtr p)
    {
        try { return Marshal.PtrToStringUTF8(p); }
        finally { wk_url_free(p); }
    }
}
