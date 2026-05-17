import Foundation
import WebkitiumSuggestionsC

/// `HistoryStore` backed by the same `browser/suggestions/` SQLite FTS5
/// index that powers URL-bar autocomplete. The history view + suggestions
/// share the `urls` table; this store reads it sorted by recency
/// (recent_history), while `FFISuggestionProvider` reads it ranked by
/// frecency+text-match (query).
///
/// One handle per profile, separate from the suggestion provider's handle
/// — SQLite handles concurrent access through its FullMutex mode and our
/// WAL journal.
actor FFIHistoryStore: HistoryStore {
    private nonisolated(unsafe) let handle: OpaquePointer?

    /// `dbPath == nil` or empty → in-memory (private windows / tests). For
    /// regular windows pass the same path as `FFISuggestionProvider`; both
    /// then talk to the SAME underlying database file.
    init(dbPath: String?) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
    }

    deinit {
        if let h = handle { wk_suggestions_close(h) }
    }

    func recent(query: String?, limit: Int) async -> [HistoryEntry] {
        guard let h = handle else { return [] }
        var results = WkSuggestionResults(rows: nil, count: 0, _opaque: nil)
        let q = query ?? ""
        let ok = q.withCString { qc -> Int32 in
            wk_suggestions_recent_history(h, qc, limit, &results)
        }
        guard ok == 1 else { return [] }
        defer { wk_suggestions_release_results(&results) }

        var out: [HistoryEntry] = []
        out.reserveCapacity(Int(results.count))
        for i in 0..<Int(results.count) {
            let row = results.rows![i]
            let title    = row.title   .map(String.init(cString:)) ?? ""
            let url      = row.subtitle.map(String.init(cString:)) ?? ""
            let visited  = Date(timeIntervalSince1970: TimeInterval(row.last_visited_ms) / 1000.0)
            out.append(HistoryEntry(
                title: title.isEmpty ? url : title,
                url: url,
                visitedAt: visited,
                favicon: BrandFavicon.match(for: title.isEmpty ? url : title)))
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

    func clear() async {
        guard let h = handle else { return }
        wk_suggestions_clear(h)
    }
}
