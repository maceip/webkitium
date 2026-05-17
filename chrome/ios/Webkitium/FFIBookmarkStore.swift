import Foundation
import WebkitiumSuggestionsC

/// `BookmarkStore` backed by the unified `browser/suggestions/` SQLite
/// database. Folders + entries live in `bookmark_folders` /
/// `bookmark_entries`; entries reference rows in `urls`, so a bookmarked
/// URL also flips `urls.is_bookmarked = 1` for ranking purposes.
///
/// Folder tree is materialized on every read (small N expected; lifting
/// to a cache is straightforward when N gets large).
actor FFIBookmarkStore: BookmarkStore {
    private nonisolated(unsafe) let handle: OpaquePointer?

    init(dbPath: String?) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
        // Seed a "Favorites" root folder if none exist yet so the UI has
        // a target on first launch.
        Task { await self.seedDefaultRootIfEmpty() }
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    private func seedDefaultRootIfEmpty() async {
        guard let h = handle else { return }
        var list = WkBookmarkFolderList(folders: nil, count: 0, _opaque: nil)
        guard wk_bookmarks_folders(h, &list) == 1 else { return }
        defer { wk_bookmarks_release_folders(&list) }
        if list.count == 0 {
            "Favorites".withCString { n in "star.fill".withCString { s in
                _ = wk_bookmarks_add_folder(h, 0, n, s)
            } }
        }
    }

    func folders() async -> [BookmarkFolder] {
        guard let h = handle else { return [] }
        var folderList = WkBookmarkFolderList(folders: nil, count: 0, _opaque: nil)
        guard wk_bookmarks_folders(h, &folderList) == 1 else { return [] }
        defer { wk_bookmarks_release_folders(&folderList) }

        // Build a (rowID → BookmarkFolder) cache and a parent → children index.
        var byID: [Int64: BookmarkFolder] = [:]
        var children: [Int64: [Int64]] = [:]
        var rootIDs: [Int64] = []
        for i in 0..<Int(folderList.count) {
            let f = folderList.folders![i]
            let name = f.name.map(String.init(cString:)) ?? ""
            let sym  = f.symbol.map(String.init(cString:)) ?? "folder"
            var bf = BookmarkFolder(name: name, symbol: sym, bookmarks: [], subfolders: [])
            // Load entries for this folder
            var entries = WkBookmarkEntryList(entries: nil, count: 0, _opaque: nil)
            if wk_bookmarks_in(h, f.id, &entries) == 1 {
                for j in 0..<Int(entries.count) {
                    let e = entries.entries![j]
                    let url   = e.url  .map(String.init(cString:)) ?? ""
                    let title = e.title.map(String.init(cString:)) ?? ""
                    bf.bookmarks.append(BookmarkEntry(
                        title: title.isEmpty ? url : title,
                        url: url,
                        favicon: BrandFavicon.match(for: title.isEmpty ? url : title)))
                }
                wk_bookmarks_release_entries(&entries)
            }
            byID[f.id] = bf
            if f.parent_id == 0 {
                rootIDs.append(f.id)
            } else {
                children[f.parent_id, default: []].append(f.id)
            }
        }
        // DFS to nest subfolders. Swift's value-type tree means we mutate
        // copies and build the immutable result bottom-up.
        func materialize(_ id: Int64) -> BookmarkFolder {
            var f = byID[id]!
            f.subfolders = (children[id] ?? []).map { materialize($0) }
            return f
        }
        return rootIDs.map { materialize($0) }
    }

    func addBookmark(_ entry: BookmarkEntry, to folderID: UUID) async {
        guard let h = handle else { return }
        // folderID is the Swift UUID of a transient BookmarkFolder. We
        // can't look it up by FFI rowid from here, so the default behavior
        // is to add to the first root folder. A proper folder picker
        // round-trips through a FolderIDMap; deferred until the UI exposes
        // an explicit "pick folder" affordance with FFI ids.
        var list = WkBookmarkFolderList(folders: nil, count: 0, _opaque: nil)
        guard wk_bookmarks_folders(h, &list) == 1, list.count > 0 else { return }
        let rootID = list.folders![0].id
        wk_bookmarks_release_folders(&list)
        entry.url.withCString { u in
            entry.title.withCString { t in
                _ = wk_bookmarks_add_entry(h, rootID, u, t)
            }
        }
    }

    func addFolder(name: String, symbol: String, parentID: UUID?) async -> BookmarkFolder {
        guard let h = handle else {
            return BookmarkFolder(name: name, symbol: symbol, bookmarks: [], subfolders: [])
        }
        name.withCString { n in
            symbol.withCString { s in
                _ = wk_bookmarks_add_folder(h, 0, n, s)
            }
        }
        return BookmarkFolder(name: name, symbol: symbol, bookmarks: [], subfolders: [])
    }
}
