import Foundation
import SwiftUI
import UIKit
import WebkitiumSuggestionsC

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

struct FFITabGroup: Identifiable, Hashable {
    let id: Int64
    var name: String
    var color: Color
}

private extension Color {
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xff) / 255.0
        let r = Double((argb >> 16) & 0xff) / 255.0
        let g = Double((argb >> 8 ) & 0xff) / 255.0
        let b = Double( argb        & 0xff) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// iOS variant: pack via UIColor instead of NSColor.
    var argbUInt32: UInt32 {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = UInt32((r.clamped() * 255).rounded()) & 0xff
        let gi = UInt32((g.clamped() * 255).rounded()) & 0xff
        let bi = UInt32((b.clamped() * 255).rounded()) & 0xff
        let ai = UInt32((a.clamped() * 255).rounded()) & 0xff
        return (ai << 24) | (ri << 16) | (gi << 8) | bi
    }
}

private extension CGFloat {
    func clamped() -> Double {
        let v = Double(self)
        return Swift.max(0.0, Swift.min(1.0, v))
    }
}
