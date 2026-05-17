import Foundation
import WebkitiumSuggestionsC

/// Persistence layer for open tabs per window. Restored on launch; written
/// after every tab list mutation. Private windows never instantiate this
/// store — their tabs stay in memory.
///
/// Window ids are stable integers assigned by the host (`BrowserWindowHost`
/// keeps a counter). Storing one row per (window_id, sort_index) means we
/// can blow away just-this-window's tabs on close and leave other windows'
/// snapshots untouched.
actor FFIOpenTabsStore {
    private nonisolated(unsafe) let handle: OpaquePointer?

    init(dbPath: String?) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    /// Load persisted tabs for a window. Empty array if none / private.
    func load(windowID: Int64) -> [PersistedTab] {
        guard let h = handle else { return [] }
        var list = WkOpenTabList(tabs: nil, count: 0, _opaque: nil)
        guard wk_open_tabs_list(h, windowID, &list) == 1 else { return [] }
        defer { wk_open_tabs_release(&list) }
        return (0..<Int(list.count)).map { i in
            let t = list.tabs![i]
            return PersistedTab(
                windowID: t.window_id,
                sortIndex: Int(t.sort_index),
                url:   t.url  .map(String.init(cString:)) ?? "",
                title: t.title.map(String.init(cString:)) ?? "",
                groupID: t.group_id,
                isPinned: t.is_pinned != 0,
                isActive: t.is_active != 0)
        }
    }

    /// Atomically replace all rows for `windowID`. Pass `[]` to drop them
    /// (e.g. on window close).
    func save(windowID: Int64, tabs: [PersistedTab]) {
        guard let h = handle else { return }
        // Build a C array of WkOpenTab, holding strong references to the
        // backing C strings for the duration of the call.
        var cTabs: [WkOpenTab] = []
        cTabs.reserveCapacity(tabs.count)
        var urlCStrings: [UnsafePointer<CChar>?] = []
        var titleCStrings: [UnsafePointer<CChar>?] = []
        // We need stable C strings; using strdup so the bytes outlive the
        // Swift String's lifetime and we free after the FFI call returns.
        for t in tabs {
            let u = strdup(t.url)
            let ti = strdup(t.title)
            urlCStrings.append(u)
            titleCStrings.append(ti)
            cTabs.append(WkOpenTab(
                window_id: t.windowID,
                sort_index: Int32(t.sortIndex),
                url: u,
                title: ti,
                group_id: t.groupID,
                is_pinned: t.isPinned ? 1 : 0,
                is_active: t.isActive ? 1 : 0))
        }
        cTabs.withUnsafeBufferPointer { buf in
            wk_open_tabs_set(h, windowID, buf.baseAddress, buf.count)
        }
        // Free strdup'd buffers.
        for p in urlCStrings   { if let p { free(UnsafeMutablePointer(mutating: p)) } }
        for p in titleCStrings { if let p { free(UnsafeMutablePointer(mutating: p)) } }
    }
}

struct PersistedTab: Hashable {
    var windowID: Int64
    var sortIndex: Int
    var url: String
    var title: String
    var groupID: Int64
    var isPinned: Bool
    var isActive: Bool
}
