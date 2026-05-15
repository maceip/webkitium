import Foundation

/// Provider protocols that sit between the SwiftUI chrome and the cross-platform browser
/// core. Today they're served by `Mock…` actors using the static catalogs. After the
/// WebKitium FFI is wired in, real implementations conforming to these same protocols
/// will replace the mocks without touching any view code.
///
/// Design rules so the protocols stay FFI-friendly:
///   • All methods are `async` — the C++ core may dispatch off the main thread.
///   • All types are `Sendable` and contain no SwiftUI types (no `Color`, no `View`).
///   • Identifiers are `String` (the FFI layer marshals these to/from C++ identifiers).
///   • Mutations return the updated state so the chrome can replace its cached snapshot
///     atomically rather than mirroring server state piecewise.

// MARK: - Suggestions

protocol SuggestionProvider: Sendable {
    /// Return the suggestion list for the given query. Empty query → empty result.
    func suggestions(for query: String) async -> [URLSuggestion]
}

actor MockSuggestionProvider: SuggestionProvider {
    static let shared = MockSuggestionProvider()
    func suggestions(for query: String) async -> [URLSuggestion] {
        let q = query.lowercased()
        guard !q.isEmpty else { return [] }
        return SuggestionCatalog.all.filter {
            $0.title.lowercased().contains(q) || $0.subtitle.lowercased().contains(q)
        }
    }
}

// MARK: - History

protocol HistoryStore: Sendable {
    /// Query visited entries. Pass `query == nil` for all entries; otherwise filter by
    /// title/url substring. Results are ordered most-recent first.
    func recent(query: String?, limit: Int) async -> [HistoryEntry]

    /// Record a visit. Real impls would write to the persistent store and notify peers
    /// for sync.
    func recordVisit(title: String, url: String) async

    /// Clear the entire history.
    func clear() async
}

actor MockHistoryStore: HistoryStore {
    static let shared = MockHistoryStore()
    private var entries: [HistoryEntry] = HistoryCatalog.recent

    func recent(query: String?, limit: Int) async -> [HistoryEntry] {
        let sorted = entries.sorted { $0.visitedAt > $1.visitedAt }
        guard let q = query?.lowercased(), !q.isEmpty else { return Array(sorted.prefix(limit)) }
        return Array(sorted.lazy.filter {
            $0.title.lowercased().contains(q) || $0.url.lowercased().contains(q)
        }.prefix(limit))
    }

    func recordVisit(title: String, url: String) async {
        entries.insert(HistoryEntry(title: title, url: url,
                                      visitedAt: Date(),
                                      favicon: BrandFavicon.match(for: title)), at: 0)
    }

    func clear() async { entries.removeAll() }
}

// MARK: - Bookmarks

protocol BookmarkStore: Sendable {
    /// Return the full folder tree (root level). Folders may contain nested subfolders.
    func folders() async -> [BookmarkFolder]

    /// Append a bookmark to the named folder.
    func addBookmark(_ entry: BookmarkEntry, to folderID: UUID) async

    /// Create a new folder. Returns the new folder so the chrome can select it.
    func addFolder(name: String, symbol: String, parentID: UUID?) async -> BookmarkFolder
}

actor MockBookmarkStore: BookmarkStore {
    static let shared = MockBookmarkStore()
    private var roots: [BookmarkFolder] = BookmarksCatalog.folders

    func folders() async -> [BookmarkFolder] { roots }

    func addBookmark(_ entry: BookmarkEntry, to folderID: UUID) async {
        roots = roots.map { $0.appending(entry, in: folderID) }
    }

    func addFolder(name: String, symbol: String, parentID: UUID?) async -> BookmarkFolder {
        let f = BookmarkFolder(name: name, symbol: symbol, bookmarks: [], subfolders: [])
        if let parent = parentID {
            roots = roots.map { $0.appendingSubfolder(f, in: parent) }
        } else {
            roots.append(f)
        }
        return f
    }
}

// MARK: - Passkeys

protocol PasskeyStore: Sendable {
    func saved() async -> [SavedPasskey]
    /// Real impls would prompt Touch ID + write to the platform keychain. The mock just
    /// appends.
    func register(site: String, username: String) async -> SavedPasskey
    func remove(_ id: UUID) async
}

actor MockPasskeyStore: PasskeyStore {
    static let shared = MockPasskeyStore()
    private var passkeys: [SavedPasskey] = PasskeyCatalog.all

    func saved() async -> [SavedPasskey] { passkeys }

    func register(site: String, username: String) async -> SavedPasskey {
        let pk = SavedPasskey(site: site, username: username,
                                createdAt: Date(), lastUsedAt: Date(),
                                favicon: BrandFavicon.match(for: site))
        passkeys.append(pk)
        return pk
    }

    func remove(_ id: UUID) async {
        passkeys.removeAll { $0.id == id }
    }
}

// MARK: - Sync devices

protocol SyncDeviceStore: Sendable {
    func paired() async -> [SyncDevice]
    /// Initiate pairing — returns a numeric/QR pairing payload that the other device
    /// scans. Real impls would expose a peer-discovery + Noise-protocol handshake.
    func startPairing() async -> PairingPayload
    func unpair(_ id: UUID) async
}

struct PairingPayload: Sendable {
    /// Six-digit numeric backup code, three-three formatted ("421 907").
    let backupCode: String
    /// Opaque payload encoded into the QR shown on screen (mock).
    let qrPayload: String
}

actor MockSyncDeviceStore: SyncDeviceStore {
    static let shared = MockSyncDeviceStore()
    private var devices: [SyncDevice] = SyncCatalog.paired

    func paired() async -> [SyncDevice] { devices }

    func startPairing() async -> PairingPayload {
        PairingPayload(backupCode: "421 907",
                        qrPayload: "webkitium-pair://v1?nonce=" + UUID().uuidString)
    }

    func unpair(_ id: UUID) async {
        devices.removeAll { $0.id == id }
    }
}

// MARK: - BookmarkFolder recursive helpers

extension BookmarkFolder {
    /// Return a copy of this folder with `entry` appended into the folder matching
    /// `folderID`. Recurses into subfolders. If no match, the folder is returned
    /// unchanged.
    func appending(_ entry: BookmarkEntry, in folderID: UUID) -> BookmarkFolder {
        var copy = self
        if id == folderID {
            copy.bookmarks.append(entry)
            return copy
        }
        copy.subfolders = subfolders.map { $0.appending(entry, in: folderID) }
        return copy
    }

    /// Return a copy of this folder with `child` appended into the folder matching
    /// `parentID`. Recurses into subfolders.
    func appendingSubfolder(_ child: BookmarkFolder, in parentID: UUID) -> BookmarkFolder {
        var copy = self
        if id == parentID {
            copy.subfolders.append(child)
            return copy
        }
        copy.subfolders = subfolders.map { $0.appendingSubfolder(child, in: parentID) }
        return copy
    }
}
