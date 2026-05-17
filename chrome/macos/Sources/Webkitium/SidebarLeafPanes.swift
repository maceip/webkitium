import SwiftUI
import WebkitiumSuggestionsC

/// Concrete panes for the "saved" sidebar leaves — Bookmarks + Reading
/// List. Read through the FFI suggestions DB; private windows pass the
/// in-memory path and naturally appear empty.

struct LeafRow: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let url: String
}

struct BookmarksLeafPane: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var rows: [LeafRow] = []

    var body: some View {
        LeafList(title: "Bookmarks", symbol: "book.closed", rows: rows)
            .task { rows = await BookmarksFetcher.flatBookmarks(isPrivate: browser.isPrivate) }
    }
}

struct ReadingListLeafPane: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var rows: [LeafRow] = []

    var body: some View {
        LeafList(title: "Reading List", symbol: "eyeglasses", rows: rows)
            .task { rows = await BookmarksFetcher.readingList(isPrivate: browser.isPrivate) }
    }
}

private struct LeafList: View {
    let title: String
    let symbol: String
    let rows: [LeafRow]
    var body: some View {
        if rows.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.title2.weight(.semibold))
                Text("Nothing here yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(rows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title).font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(row.url).font(.system(size: 11)).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset)
        }
    }
}

/// One-shot FFI read helpers. The pane views don't need persistent
/// handles — they re-open SQLite on demand.
enum BookmarksFetcher {
    static func flatBookmarks(isPrivate: Bool) async -> [LeafRow] {
        await read(isPrivate: isPrivate, kind: .bookmarks)
    }
    static func readingList(isPrivate: Bool) async -> [LeafRow] {
        await read(isPrivate: isPrivate, kind: .readingList)
    }

    private enum Kind { case bookmarks, readingList }

    private static func read(isPrivate: Bool, kind: Kind) async -> [LeafRow] {
        guard !isPrivate, let cPath = ProfileDB.path() else { return [] }
        guard let h = cPath.withCString({ wk_suggestions_open($0) }) else { return [] }
        defer { wk_suggestions_close(h) }
        var list = WkSuggestionResults(rows: nil, count: 0, _opaque: nil)
        let ok: Int32 = {
            switch kind {
            case .bookmarks:   return wk_suggestions_bookmarks_flat(h, 200, &list)
            case .readingList: return wk_suggestions_reading_list(h, 200, &list)
            }
        }()
        guard ok == 1 else { return [] }
        defer { wk_suggestions_release_results(&list) }
        return (0..<Int(list.count)).map { i in
            let r = list.rows![i]
            return LeafRow(
                title: r.title.map(String.init(cString:)) ?? "",
                url:   r.subtitle.map(String.init(cString:)) ?? "")
        }
    }
}

/// Single source of truth for the profile DB location. Shared with
/// `BrowserWindowHost.defaultSuggestionsDBPath` (kept identical so any
/// new FFI handle hits the same file).
enum ProfileDB {
    static func path() -> String? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory,
                                        in: .userDomainMask).first else { return nil }
        let dir = appSupport.appendingPathComponent("Webkitium", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("suggestions.db").path
    }
}
