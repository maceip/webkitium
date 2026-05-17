// P/Invoke wrappers for browser/suggestions/SuggestionsBridgeC.h.
//
// Lifecycle: Open() returns an IDisposable that owns the native handle —
// every caller wraps it in a `using` block. Every query/list call that
// returns rows must be paired with a release_results call; that pairing
// is enforced here by RAII handles (Results / BookmarksResults).

using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

namespace Webkitium.FFI;

public enum SuggestionKind
{
    TopHit = 0,
    History = 1,
    Bookmark = 2,
    Search = 3,
    Site = 4,
}

public readonly record struct Suggestion(
    SuggestionKind Kind,
    string Title,
    string Subtitle,
    string? IconHint,
    double Score,
    long LastVisitedMs);

public readonly record struct BookmarkRow(string Title, string Url);

public sealed partial class SuggestionsIndex : IDisposable
{
    private const string Dll = "webkitium_core";

    private IntPtr _handle;
    private bool _disposed;

    // ---- Lifecycle ----

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial IntPtr wk_suggestions_open(string db_path);

    [LibraryImport(Dll)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_close(IntPtr index);

    [LibraryImport(Dll)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_clear(IntPtr index);

    // ---- Visit / bookmark / reading-list mutations ----

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_record_visit(IntPtr index, string title, string url);

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_set_bookmarked(IntPtr index, string url, int is_bookmarked);

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_set_in_reading_list(IntPtr index, string url, int in_list);

    // ---- Query / list ----

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial int wk_suggestions_query(IntPtr index, string query, nuint limit, ref WkSuggestionResults out_results);

    [LibraryImport(Dll, StringMarshalling = StringMarshalling.Utf8)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial int wk_suggestions_bookmarks_flat(IntPtr index, nuint limit, ref WkSuggestionResults out_results);

    [LibraryImport(Dll)]
    [UnmanagedCallConv(CallConvs = new[] { typeof(CallConvCdecl) })]
    private static partial void wk_suggestions_release_results(ref WkSuggestionResults results);

    // ---- Public surface ----

    /// <param name="dbPath">Empty string opens an in-memory DB (private windows).</param>
    public static SuggestionsIndex Open(string dbPath)
    {
        var h = wk_suggestions_open(dbPath);
        if (h == IntPtr.Zero) throw new InvalidOperationException($"wk_suggestions_open failed for '{dbPath}'");
        return new SuggestionsIndex(h);
    }

    private SuggestionsIndex(IntPtr handle) { _handle = handle; }

    public void RecordVisit(string title, string url)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        wk_suggestions_record_visit(_handle, title ?? string.Empty, url);
    }

    public void SetBookmarked(string url, bool bookmarked)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        wk_suggestions_set_bookmarked(_handle, url, bookmarked ? 1 : 0);
    }

    public void SetInReadingList(string url, bool inList)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        wk_suggestions_set_in_reading_list(_handle, url, inList ? 1 : 0);
    }

    /// <summary>
    /// Synchronous because the underlying C call is already fast (SQLite FTS5
    /// on an in-process file). Free-threaded — safe to call from any thread.
    /// </summary>
    public IReadOnlyList<Suggestion> Query(string prefix, int limit = 8)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        if (string.IsNullOrWhiteSpace(prefix)) return Array.Empty<Suggestion>();

        var results = default(WkSuggestionResults);
        int ok = wk_suggestions_query(_handle, prefix, (nuint)limit, ref results);
        if (ok != 1) return Array.Empty<Suggestion>();
        try { return MarshalRows(in results); }
        finally { wk_suggestions_release_results(ref results); }
    }

    public IReadOnlyList<BookmarkRow> BookmarksFlat(int limit = 64)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        var results = default(WkSuggestionResults);
        int ok = wk_suggestions_bookmarks_flat(_handle, (nuint)limit, ref results);
        if (ok != 1) return Array.Empty<BookmarkRow>();
        try
        {
            var rows = MarshalRows(in results);
            var list = new List<BookmarkRow>(rows.Count);
            foreach (var r in rows) list.Add(new BookmarkRow(r.Title, r.Subtitle));
            return list;
        }
        finally { wk_suggestions_release_results(ref results); }
    }

    public bool IsBookmarked(string url)
    {
        if (_disposed) throw new ObjectDisposedException(nameof(SuggestionsIndex));
        foreach (var b in BookmarksFlat(256))
            if (string.Equals(b.Url, url, StringComparison.Ordinal)) return true;
        return false;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        if (_handle != IntPtr.Zero)
        {
            wk_suggestions_close(_handle);
            _handle = IntPtr.Zero;
        }
        GC.SuppressFinalize(this);
    }

    ~SuggestionsIndex() { Dispose(); }

    // ---- Marshalling ----

    [StructLayout(LayoutKind.Sequential)]
    private struct WkSuggestionResults
    {
        public IntPtr Rows;   // const WkSuggestionRow*
        public nuint Count;
        public IntPtr Opaque;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct WkSuggestionRow
    {
        public int Kind;
        public IntPtr Title;     // const char*
        public IntPtr Subtitle;
        public IntPtr IconHint;
        public double Score;
        public long LastVisitedMs;
    }

    private static List<Suggestion> MarshalRows(in WkSuggestionResults results)
    {
        int count = checked((int)results.Count);
        var list = new List<Suggestion>(count);
        int stride = Marshal.SizeOf<WkSuggestionRow>();
        for (int i = 0; i < count; i++)
        {
            var rowPtr = results.Rows + i * stride;
            var row = Marshal.PtrToStructure<WkSuggestionRow>(rowPtr);
            list.Add(new Suggestion(
                Kind: (SuggestionKind)row.Kind,
                Title: Marshal.PtrToStringUTF8(row.Title) ?? string.Empty,
                Subtitle: Marshal.PtrToStringUTF8(row.Subtitle) ?? string.Empty,
                IconHint: Marshal.PtrToStringUTF8(row.IconHint),
                Score: row.Score,
                LastVisitedMs: row.LastVisitedMs));
        }
        return list;
    }
}
