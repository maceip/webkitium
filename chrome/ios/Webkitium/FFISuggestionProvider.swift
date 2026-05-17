import Foundation
import WebkitiumSuggestionsC

/// `SuggestionProvider` backed by the cross-platform `browser/suggestions/`
/// SQLite FTS5 index. One handle per profile; private windows pass an empty
/// path so the index lives in-memory and dies with the window.
///
/// All FFI calls run inside the actor, which serializes them — the C++ side
/// is already thread-safe via an internal mutex, but funneling through the
/// actor keeps `BrowserViewModel`'s async-await call sites clean.
actor FFISuggestionProvider: SuggestionProvider {
    /// `nonisolated(unsafe)` because `deinit` must touch the handle to free
    /// it, and Swift 6 strict concurrency otherwise rejects the cross-isolation
    /// access. The C++ side handles its own threading.
    private nonisolated(unsafe) let handle: OpaquePointer?

    /// `dbPath == nil` or empty → in-memory index (used for private windows
    /// and unit tests).
    init(dbPath: String?) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
    }

    deinit {
        if let h = handle { wk_suggestions_close(h) }
    }

    func suggestions(for query: String) async -> [URLSuggestion] {
        guard let h = handle, !query.isEmpty else { return [] }
        var results = WkSuggestionResults(rows: nil, count: 0, _opaque: nil)
        let ok = query.withCString { q -> Int32 in
            wk_suggestions_query(h, q, 8, &results)
        }
        guard ok == 1 else { return [] }
        defer { wk_suggestions_release_results(&results) }

        var out: [URLSuggestion] = []
        out.reserveCapacity(Int(results.count))
        for i in 0..<Int(results.count) {
            let row = results.rows![i]
            let title    = row.title    .map(String.init(cString:)) ?? ""
            let subtitle = row.subtitle .map(String.init(cString:)) ?? ""
            out.append(URLSuggestion(
                kind: mapKind(row.kind),
                title: title,
                subtitle: subtitle,
                favicon: BrandFavicon.match(for: title.isEmpty ? subtitle : title)
            ))
        }
        return out
    }

    func recordVisit(title: String, url: String) async {
        guard let h = handle else { return }
        title.withCString { t in
            url.withCString { u in
                wk_suggestions_record_visit(h, t, u)
            }
        }
    }

    func setBookmarked(url: String, isBookmarked: Bool) async {
        guard let h = handle else { return }
        url.withCString { u in
            wk_suggestions_set_bookmarked(h, u, isBookmarked ? 1 : 0)
        }
    }

    private func mapKind(_ k: WkSuggestionKind) -> URLSuggestion.Kind {
        switch k {
        case WK_SUGGESTION_KIND_TOP_HIT:  return .topHit
        case WK_SUGGESTION_KIND_HISTORY:  return .history
        case WK_SUGGESTION_KIND_BOOKMARK: return .bookmark
        case WK_SUGGESTION_KIND_SEARCH:   return .search
        case WK_SUGGESTION_KIND_SITE:     return .history
        default:                          return .history
        }
    }
}
