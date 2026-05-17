import Foundation
import WebkitiumUrlC

/// Display-side view of the URL-bar search engines. URL construction
/// lives in C++ (`browser/url/`) — this Swift enum is purely the table
/// the Settings UI renders and the rawValue we hand to the FFI.
enum SearchEngine: String, CaseIterable, Identifiable {
    case duckduckgo
    case brave
    case kagi
    case google

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .duckduckgo: return "DuckDuckGo"
        case .brave:      return "Brave Search"
        case .kagi:       return "Kagi"
        case .google:     return "Google"
        }
    }

    var faviconSymbol: String {
        switch self {
        case .duckduckgo: return "shield"
        case .brave:      return "flame"
        case .kagi:       return "key"
        case .google:     return "magnifyingglass.circle"
        }
    }

    /// Privacy-first default. Persisted per-profile via `@AppStorage`.
    static var defaultEngine: SearchEngine { .duckduckgo }
}

/// Thin Swift wrappers around the `WebkitiumUrlC` ABI. All allocated C
/// strings are freed via `wk_url_free` before returning.
enum URLBridge {

    /// Currently selected engine id. Reads `UserDefaults` directly so it
    /// stays callable from non-MainActor code paths. The Settings UI
    /// writes the same key via `@AppStorage`.
    static var currentEngineID: String {
        UserDefaults.standard.string(forKey: "Webkitium.SearchEngine")
            ?? SearchEngine.defaultEngine.rawValue
    }

    enum NormalizedInput {
        case url(URL)
        case invalid
    }

    /// URL normalization with implicit search-fallback. Returns a single
    /// URL the webview can load directly, or `.invalid` for empty input.
    static func normalize(_ raw: String, engineID: String? = nil) -> URL? {
        let engine = engineID ?? currentEngineID
        var outPtr: UnsafeMutablePointer<CChar>? = nil
        let kind = raw.withCString { rawCStr in
            engine.withCString { engineCStr in
                wk_url_normalize(rawCStr, engineCStr, &outPtr)
            }
        }
        guard kind >= 0, let outPtr else { return nil }
        defer { wk_url_free(outPtr) }
        return URL(string: String(cString: outPtr))
    }

    /// Strip known tracking parameters (`utm_*`, `fbclid`, etc).
    static func scrubTracking(_ url: String) -> String {
        guard let outPtr = url.withCString({ wk_url_scrub_tracking($0) }) else {
            return url
        }
        defer { wk_url_free(outPtr) }
        return String(cString: outPtr)
    }

    /// Build a search URL for the given engine + query.
    static func searchURL(engineID: String? = nil, query: String) -> URL? {
        let engine = engineID ?? currentEngineID
        let outPtr: UnsafeMutablePointer<CChar>? = engine.withCString { engineCStr in
            query.withCString { qCStr in
                wk_search_engine_search_url(engineCStr, qCStr)
            }
        }
        guard let outPtr else { return nil }
        defer { wk_url_free(outPtr) }
        return URL(string: String(cString: outPtr))
    }

    /// Build a suggestion-API URL. Nil for engines without one (Kagi).
    static func suggestURL(engineID: String? = nil, query: String) -> URL? {
        let engine = engineID ?? currentEngineID
        let outPtr: UnsafeMutablePointer<CChar>? = engine.withCString { engineCStr in
            query.withCString { qCStr in
                wk_search_engine_suggest_url(engineCStr, qCStr)
            }
        }
        guard let outPtr else { return nil }
        defer { wk_url_free(outPtr) }
        return URL(string: String(cString: outPtr))
    }
}
