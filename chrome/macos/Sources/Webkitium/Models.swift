import SwiftUI

// MARK: - Tab

/// A browser tab. Fields split into two halves:
///
///   • **Core fields** (projected from the C++ core's `ng::BrowserTab` POD): `id`,
///     `title`, `url`, `isPinned`, `discarded`, `isLoading`, `loadProgress`,
///     `canGoBack`, `canGoForward`. These are observed values pushed in by the platform
///     WebView host (KVO on Apple, signal handlers on other platforms) — the chrome
///     never mutates them directly.
///
///   • **Chrome-only fields**: `favicon`, `audio`, `hasReaderMode`, `tabGroupID`. These
///     are UI/chrome state owned by SwiftUI; the C++ core doesn't know about them.
///
/// Keeping the split explicit makes the FFI boundary obvious: when wiring `WebKitium`
/// in, the WebView host writes the core fields; the chrome continues to own the rest.
struct Tab: Identifiable, Hashable {
    let id = UUID()

    // Core (projected from ng::BrowserTab + WebView observations)
    var title: String
    var url: String = ""
    var isPinned: Bool = false
    var discarded: Bool = false        // matches `ng::BrowserTab.discarded`
    var isLoading: Bool = false
    var loadProgress: Double = 0       // 0…1, drives the URL-bar progress fill
    var canGoBack: Bool = false
    var canGoForward: Bool = false

    // Chrome-only
    var favicon: BrandFavicon
    var audio: AudioState = .none
    var hasReaderMode: Bool = false    // shows reader icon on URL bar when true
    var tabGroupID: UUID?              // nil = ungrouped; matches `TabGroup.id`

    enum AudioState: Hashable { case none, playing, muted }
}

/// Brand favicon — synthesizes the small colored badge next to a tab/sidebar entry.
/// Values mirror the AppKit `hostFavicons` table so the visual remains identical.
enum BrandFavicon: Hashable {
    case apple                 // white square with black apple.logo
    case google                // pale circle with black "G"
    case generic(symbol: String)

    static func match(for title: String) -> BrandFavicon {
        let lower = title.lowercased()
        if lower.contains("google") || lower.contains("android") { return .google }
        if lower.contains("apple") { return .apple }
        return .generic(symbol: "globe")
    }

    @ViewBuilder
    func view(size: CGFloat = 14) -> some View {
        switch self {
        case .apple:
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous).fill(.white)
                Image(systemName: "apple.logo")
                    .font(.system(size: size * 0.7, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: size, height: size)
        case .google:
            ZStack {
                Circle().fill(Color(.sRGB, red: 0.92, green: 0.92, blue: 0.94, opacity: 1))
                Text("G")
                    .font(.system(size: size * 0.65, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: size, height: size)
        case .generic(let symbol):
            Image(systemName: symbol)
                .font(.system(size: size * 0.9))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Sidebar items (Saved section)

enum SidebarLeaf: Hashable, CaseIterable, Identifiable {
    case bookmarks, readingList, sharedWithYou
    var id: Self { self }
    var title: String {
        switch self {
        case .bookmarks: return "Bookmarks"
        case .readingList: return "Reading List"
        case .sharedWithYou: return "Shared with You"
        }
    }
    var symbol: String {
        switch self {
        case .bookmarks: return "book.closed"
        case .readingList: return "eyeglasses"
        case .sharedWithYou: return "person.2"
        }
    }
}

// MARK: - Sidebar selection (drives navigation + highlight)

enum SidebarSelection: Hashable {
    case tab(UUID)
    case leaf(SidebarLeaf)
}

// MARK: - URL bar suggestions

struct URLSuggestion: Identifiable, Hashable {
    let id = UUID()
    var kind: Kind
    var title: String
    var subtitle: String   // typically the URL
    var favicon: BrandFavicon

    enum Kind: Hashable {
        case topHit         // best match — bold accent treatment
        case history
        case bookmark
        case search         // search-engine suggestion
    }

    var symbol: String {
        switch kind {
        case .topHit:   return "arrow.right.circle.fill"
        case .history:  return "clock"
        case .bookmark: return "book.closed"
        case .search:   return "magnifyingglass"
        }
    }
}

enum SuggestionCatalog {
    /// Mock suggestions for the URL bar dropdown. Filtered by typed query in the view.
    static let all: [URLSuggestion] = [
        .init(kind: .topHit,   title: "apple.com",      subtitle: "https://www.apple.com", favicon: .apple),
        .init(kind: .history,  title: "Apple Newsroom", subtitle: "apple.com/newsroom",     favicon: .apple),
        .init(kind: .bookmark, title: "Apple Developer",subtitle: "developer.apple.com",   favicon: .apple),
        .init(kind: .history,  title: "Google",         subtitle: "google.com",            favicon: .google),
        .init(kind: .history,  title: "android* - Google Search", subtitle: "google.com/search?q=android",
              favicon: .google),
        .init(kind: .search,   title: "Search the web for…",      subtitle: "Google",      favicon: .google),
    ]
}

// MARK: - Find on page

enum FindMode: Hashable, CaseIterable, Identifiable {
    case contains, beginsWith
    var id: Self { self }
    var title: String { self == .contains ? "Contains" : "Begins with" }
}

// MARK: - Downloads

struct DownloadItem: Identifiable, Hashable {
    let id = UUID()
    var filename: String
    var sizeText: String
    var progress: Double   // 0…1; 1 = completed
    var isCompleted: Bool { progress >= 1 }
    var icon: String { "doc.fill" }
}

enum DownloadsCatalog {
    static let recent: [DownloadItem] = [
        .init(filename: "Q3-Report.pdf",   sizeText: "2.4 MB", progress: 1.0),
        .init(filename: "vacation.jpg",    sizeText: "1.1 MB", progress: 1.0),
        .init(filename: "SwiftUI-Recap.mp4", sizeText: "18.2 / 42 MB", progress: 0.43),
    ]
}

// MARK: - Profiles

struct BrowserProfile: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var tintHex: UInt32
    var symbol: String
    var color: Color {
        Color(.sRGB,
              red:   Double((tintHex >> 16) & 0xff) / 255.0,
              green: Double((tintHex >> 8)  & 0xff) / 255.0,
              blue:  Double(tintHex         & 0xff) / 255.0,
              opacity: 1)
    }
}

enum ProfileCatalog {
    static let all: [BrowserProfile] = [
        .init(name: "Personal", tintHex: 0xc77859, symbol: "person.crop.circle.fill"),
        .init(name: "Work",     tintHex: 0x2c64d0, symbol: "briefcase.fill"),
        .init(name: "Study",    tintHex: 0x4b9b41, symbol: "graduationcap.fill"),
    ]
}

// MARK: - Site settings (per-site permissions)

struct SitePermission: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var symbol: String
    var options: [String]
    var current: String
}

enum SitePermissionCatalog {
    static let defaults: [SitePermission] = [
        .init(title: "Auto-Play",        symbol: "play.rectangle.fill",
              options: ["Allow All Auto-Play", "Stop Media with Sound", "Never Auto-Play"],
              current: "Stop Media with Sound"),
        .init(title: "Page Zoom",        symbol: "plus.magnifyingglass",
              options: ["50%", "75%", "85%", "100%", "115%", "125%", "150%", "200%"],
              current: "100%"),
        .init(title: "Camera",           symbol: "camera.fill",
              options: ["Ask", "Deny", "Allow"], current: "Ask"),
        .init(title: "Microphone",       symbol: "mic.fill",
              options: ["Ask", "Deny", "Allow"], current: "Ask"),
        .init(title: "Location",         symbol: "location.fill",
              options: ["Ask", "Deny", "Allow"], current: "Ask"),
        .init(title: "Notifications",    symbol: "bell.fill",
              options: ["Ask", "Deny", "Allow"], current: "Deny"),
        .init(title: "Pop-up Windows",   symbol: "rectangle.on.rectangle",
              options: ["Block and Notify", "Block", "Allow"], current: "Block and Notify"),
        .init(title: "Content Blockers", symbol: "shield.fill",
              options: ["On", "Off"], current: "On"),
        .init(title: "Reader",           symbol: "doc.plaintext",
              options: ["Automatic", "Manual"], current: "Manual"),
    ]
}

// MARK: - Favorites (Start Page)

struct Favorite: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let symbol: String     // SF Symbol used as placeholder logo
    let tintHex: UInt32    // sRGB packed color for the icon background
    let url: String        // canonical URL — drives hover status bar
    var tint: Color {
        Color(.sRGB,
              red: Double((tintHex >> 16) & 0xff) / 255.0,
              green: Double((tintHex >> 8) & 0xff) / 255.0,
              blue: Double(tintHex & 0xff) / 255.0,
              opacity: 1)
    }
}

enum FavoritesCatalog {
    static let all: [Favorite] = [
        .init(title: "Apple",          symbol: "apple.logo",      tintHex: 0xffffff,
              url: "https://www.apple.com"),
        .init(title: "iCloud",         symbol: "cloud.fill",      tintHex: 0x29b6f6,
              url: "https://www.icloud.com"),
        .init(title: "Yahoo",          symbol: "questionmark.diamond.fill", tintHex: 0x6f1ab1,
              url: "https://www.yahoo.com"),
        .init(title: "Bing",           symbol: "magnifyingglass", tintHex: 0x2b81d6,
              url: "https://www.bing.com"),
        .init(title: "Google",         symbol: "g.circle.fill",   tintHex: 0x4285f4,
              url: "https://www.google.com"),
        .init(title: "Wikipedia",      symbol: "w.circle.fill",   tintHex: 0xffffff,
              url: "https://en.wikipedia.org"),
        .init(title: "Facebook",       symbol: "f.circle.fill",   tintHex: 0x1877f2,
              url: "https://www.facebook.com"),
        .init(title: "Twitter",        symbol: "xmark",           tintHex: 0x000000,
              url: "https://twitter.com"),
        .init(title: "LinkedIn",       symbol: "person.crop.square.filled.and.at.rectangle", tintHex: 0x0e76a8,
              url: "https://www.linkedin.com"),
        .init(title: "The Weather Channel", symbol: "cloud.sun.fill", tintHex: 0x4ba3da,
              url: "https://weather.com"),
        .init(title: "Yelp",           symbol: "y.circle.fill",   tintHex: 0xd32323,
              url: "https://www.yelp.com"),
        .init(title: "TripAdvisor",    symbol: "binoculars.fill", tintHex: 0x39c25e,
              url: "https://www.tripadvisor.com"),
    ]
}

// MARK: - History

struct HistoryEntry: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var url: String
    var visitedAt: Date
    var favicon: BrandFavicon

    enum Bucket: Hashable, CaseIterable {
        case today, yesterday, earlier
        var title: String {
            switch self {
            case .today:     return "Today"
            case .yesterday: return "Yesterday"
            case .earlier:   return "Earlier This Week"
            }
        }
    }
}

enum HistoryCatalog {
    static let recent: [HistoryEntry] = {
        let now = Date()
        let cal = Calendar.current
        func d(_ offset: TimeInterval) -> Date { now.addingTimeInterval(offset) }
        return [
            .init(title: "Apple",                       url: "https://www.apple.com",          visitedAt: d(-60 * 12),  favicon: .apple),
            .init(title: "Apple Newsroom",              url: "https://www.apple.com/newsroom", visitedAt: d(-60 * 45),  favicon: .apple),
            .init(title: "Hacker News",                 url: "https://news.ycombinator.com",   visitedAt: d(-60 * 90),  favicon: .generic(symbol: "n.square.fill")),
            .init(title: "android* - Google Search",    url: "https://google.com/search?q=android", visitedAt: d(-60 * 120), favicon: .google),
            .init(title: "Apple Developer",             url: "https://developer.apple.com",
                  visitedAt: cal.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(-60 * 35), favicon: .apple),
            .init(title: "Swift.org",                   url: "https://www.swift.org",
                  visitedAt: cal.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(-60 * 70), favicon: .generic(symbol: "swift")),
            .init(title: "GitHub – swiftui/Examples",   url: "https://github.com/swiftui/Examples",
                  visitedAt: cal.date(byAdding: .day, value: -3, to: now)!, favicon: .generic(symbol: "chevron.left.forwardslash.chevron.right")),
            .init(title: "Wikipedia – Liquid Glass",    url: "https://en.wikipedia.org/wiki/Liquid_Glass",
                  visitedAt: cal.date(byAdding: .day, value: -4, to: now)!, favicon: .generic(symbol: "w.circle.fill")),
        ]
    }()

    static func bucket(for date: Date, now: Date = Date()) -> HistoryEntry.Bucket {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return .today }
        if cal.isDateInYesterday(date) { return .yesterday }
        return .earlier
    }
}

// MARK: - Bookmarks

struct BookmarkEntry: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var url: String
    var favicon: BrandFavicon
}

struct BookmarkFolder: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var symbol: String
    var bookmarks: [BookmarkEntry]
    /// Nested subfolders — Safari supports arbitrary-depth folder trees. Empty for leaf
    /// folders.
    var subfolders: [BookmarkFolder] = []
}

enum BookmarksCatalog {
    static let folders: [BookmarkFolder] = [
        .init(name: "Favorites", symbol: "star.fill", bookmarks: [
            .init(title: "Apple",            url: "https://www.apple.com",          favicon: .apple),
            .init(title: "Apple Developer",  url: "https://developer.apple.com",    favicon: .apple),
            .init(title: "iCloud",           url: "https://www.icloud.com",         favicon: .generic(symbol: "cloud.fill")),
        ]),
        .init(name: "News",      symbol: "newspaper.fill", bookmarks: [
            .init(title: "Hacker News",      url: "https://news.ycombinator.com",   favicon: .generic(symbol: "n.square.fill")),
            .init(title: "The Verge",        url: "https://www.theverge.com",       favicon: .generic(symbol: "v.circle.fill")),
        ], subfolders: [
            .init(name: "Tech",  symbol: "cpu",     bookmarks: [
                .init(title: "Ars Technica",  url: "https://arstechnica.com",         favicon: .generic(symbol: "a.circle.fill")),
                .init(title: "Daring Fireball", url: "https://daringfireball.net",    favicon: .generic(symbol: "flame.fill")),
            ]),
        ]),
        .init(name: "Research",  symbol: "graduationcap.fill", bookmarks: [
            .init(title: "Swift.org",        url: "https://www.swift.org",          favicon: .generic(symbol: "swift")),
            .init(title: "Hacker News",      url: "https://news.ycombinator.com",   favicon: .generic(symbol: "n.square.fill")),
        ], subfolders: [
            .init(name: "Apple", symbol: "apple.logo", bookmarks: [
                .init(title: "WWDC Videos",   url: "https://developer.apple.com/videos", favicon: .apple),
                .init(title: "Human Interface Guidelines",
                      url: "https://developer.apple.com/design/human-interface-guidelines",
                      favicon: .apple),
            ]),
        ]),
    ]
}

// MARK: - Tab Groups

struct TabGroup: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var tintHex: UInt32
    var symbol: String
    var color: Color {
        Color(.sRGB,
              red:   Double((tintHex >> 16) & 0xff) / 255.0,
              green: Double((tintHex >> 8)  & 0xff) / 255.0,
              blue:  Double(tintHex         & 0xff) / 255.0,
              opacity: 1)
    }
}

enum TabGroupCatalog {
    static let all: [TabGroup] = [
        .init(name: "Today",     tintHex: 0x4b9b41, symbol: "circle.grid.2x2"),
        .init(name: "Reading",   tintHex: 0xc77859, symbol: "eyeglasses"),
        .init(name: "Shopping",  tintHex: 0xc44d4d, symbol: "bag.fill"),
    ]
}

// MARK: - Passkeys

struct SavedPasskey: Identifiable, Hashable {
    let id = UUID()
    var site: String
    var username: String
    var createdAt: Date
    var lastUsedAt: Date
    var favicon: BrandFavicon
}

enum PasskeyCatalog {
    static let all: [SavedPasskey] = {
        let now = Date()
        return [
            .init(site: "apple.com",          username: "ryan@icloud.com",     createdAt: now.addingTimeInterval(-86_400 * 30),
                  lastUsedAt: now.addingTimeInterval(-3_600),                  favicon: .apple),
            .init(site: "github.com",         username: "ryanmac",             createdAt: now.addingTimeInterval(-86_400 * 90),
                  lastUsedAt: now.addingTimeInterval(-86_400 * 2),             favicon: .generic(symbol: "chevron.left.forwardslash.chevron.right")),
            .init(site: "google.com",         username: "ryan.macarthur",      createdAt: now.addingTimeInterval(-86_400 * 200),
                  lastUsedAt: now.addingTimeInterval(-86_400 * 14),            favicon: .google),
            .init(site: "developer.apple.com",username: "ryan@icloud.com",     createdAt: now.addingTimeInterval(-86_400 * 45),
                  lastUsedAt: now.addingTimeInterval(-86_400 * 5),             favicon: .apple),
        ]
    }()
}

// MARK: - Sync devices

struct SyncDevice: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var kind: Kind
    var lastSync: Date
    enum Kind: Hashable {
        case mac, iPhone, iPad, appleWatch
        var symbol: String {
            switch self {
            case .mac:        return "laptopcomputer"
            case .iPhone:     return "iphone"
            case .iPad:       return "ipad"
            case .appleWatch: return "applewatch"
            }
        }
    }
}

enum SyncCatalog {
    static let paired: [SyncDevice] = [
        .init(name: "Ryan's MacBook Pro", kind: .mac,    lastSync: Date().addingTimeInterval(-60)),
        .init(name: "Ryan's iPhone 16",   kind: .iPhone, lastSync: Date().addingTimeInterval(-300)),
    ]
}

// MARK: - Translation

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case english     = "English"
    case spanish     = "Spanish"
    case french      = "French"
    case german      = "German"
    case italian     = "Italian"
    case japanese    = "Japanese"
    case korean      = "Korean"
    case chinese     = "Chinese (Simplified)"
    case portuguese  = "Portuguese"
    var id: String { rawValue }
}
