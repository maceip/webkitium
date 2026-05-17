import Foundation
import SwiftUI
import WebkitiumSuggestionsC

/// Tab-group persistence backed by the unified `browser/suggestions/`
/// SQLite database. Groups have a name + an `ARGB` color packed into a
/// `UInt32`. Add/remove are write-through; the in-memory list is
/// refreshed from the DB after each mutation.
@MainActor
@Observable
final class FFITabGroupStore {
    private(set) var groups: [FFITabGroup] = []
    private nonisolated(unsafe) let handle: OpaquePointer?

    init(dbPath: String?) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
        reload()
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    func reload() {
        guard let h = handle else { groups = []; return }
        var list = WkTabGroupList(groups: nil, count: 0, _opaque: nil)
        guard wk_tab_groups_list(h, &list) == 1 else { groups = []; return }
        defer { wk_tab_groups_release(&list) }
        groups = (0..<Int(list.count)).map { i in
            let g = list.groups![i]
            return FFITabGroup(
                id: g.id,
                name: g.name.map(String.init(cString:)) ?? "",
                color: Color(argb: g.color_argb))
        }
    }

    @discardableResult
    func add(name: String, color: Color) -> Int64 {
        guard let h = handle else { return 0 }
        let argb = color.argbUInt32
        let id = name.withCString { wk_tab_groups_add(h, $0, argb) }
        reload()
        return id
    }

    func remove(id: Int64) {
        guard let h = handle else { return }
        wk_tab_groups_remove(h, id)
        reload()
    }
}

/// Lightweight UI-facing tab group. The FFI rowid is the stable identity.
/// FFI-backed tab group (Int64 rowid). The pre-existing UI `TabGroup`
/// (UUID-keyed, in Models.swift) is rebuilt from this on every reload.
struct FFITabGroup: Identifiable, Hashable {
    let id: Int64
    var name: String
    var color: Color
}

private extension Color {
    /// Build a Color from a packed 0xAARRGGBB UInt32.
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xff) / 255.0
        let r = Double((argb >> 16) & 0xff) / 255.0
        let g = Double((argb >> 8 ) & 0xff) / 255.0
        let b = Double( argb        & 0xff) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Best-effort packing of a Color back into 0xAARRGGBB. Goes through
    /// NSColor on macOS, which can resolve dynamic / system colors.
    var argbUInt32: UInt32 {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .clear
        let r = UInt32((ns.redComponent  .clamped() * 255).rounded()) & 0xff
        let g = UInt32((ns.greenComponent.clamped() * 255).rounded()) & 0xff
        let b = UInt32((ns.blueComponent .clamped() * 255).rounded()) & 0xff
        let a = UInt32((ns.alphaComponent.clamped() * 255).rounded()) & 0xff
        return (a << 24) | (r << 16) | (g << 8) | b
    }
}

private extension CGFloat {
    func clamped() -> Double {
        let v = Double(self)
        return Swift.max(0.0, Swift.min(1.0, v))
    }
}
