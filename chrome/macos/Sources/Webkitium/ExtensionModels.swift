import SwiftUI

/// A browser extension as exposed to our UI. Identifier + presentation metadata + state.
struct BrowserExtension: Equatable, Identifiable, Hashable {
    let id: String
    var name: String
    var author: String
    var version: String
    var summary: String
    var detail: String
    var iconTintHex: UInt32   // sRGB packed color for placeholder icon
    var iconGlyph: String     // First initial
    var permissions: [String]
    var isEnabled: Bool
    var hasToolbarButton: Bool
    var hasOptionsPage: Bool
    var price: Double?
    var rating: Double?
    var ratingCount: Int?
    var category: String?

    var iconColor: Color {
        Color(.sRGB,
              red: Double((iconTintHex >> 16) & 0xff) / 255.0,
              green: Double((iconTintHex >> 8) & 0xff) / 255.0,
              blue: Double(iconTintHex & 0xff) / 255.0,
              opacity: 1)
    }
}

/// Placeholder icon for an extension — same rendering as the AppKit version.
struct ExtensionIcon: View {
    let ext: BrowserExtension
    var size: CGFloat = 32
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(ext.iconColor)
            Text(ext.iconGlyph.uppercased())
                .font(.system(size: size * 0.55, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

enum ExtensionCatalog {
    static let installed: [BrowserExtension] = [
        .init(id: "com.example.adblock",
              name: "AdBlock Lite", author: "Frosty Software", version: "3.2.1",
              summary: "Blocks ads and tracking scripts on every page.",
              detail: "AdBlock Lite uses curated EasyList rulesets compiled into Content Blocker JSON to keep page rendering fast while filtering ads. No personal data leaves your machine.",
              iconTintHex: 0x5980f0, iconGlyph: "A",
              permissions: ["Read and modify webpage content", "Access browsing history"],
              isEnabled: true, hasToolbarButton: true, hasOptionsPage: true,
              price: nil, rating: nil, ratingCount: nil, category: "Privacy"),
        .init(id: "com.example.dictionary",
              name: "QuickDictionary", author: "Lexicon Labs", version: "1.4.0",
              summary: "Inline definitions on any selected word.",
              detail: "Select a word in any page and QuickDictionary shows a compact definition popover. Offline dictionary is bundled; specialty terms fall back to a remote lookup.",
              iconTintHex: 0xf08c59, iconGlyph: "D",
              permissions: ["Read selected text"],
              isEnabled: true, hasToolbarButton: true, hasOptionsPage: false,
              price: nil, rating: nil, ratingCount: nil, category: "Productivity"),
        .init(id: "com.example.darkpages",
              name: "DarkPages", author: "Nocturne Inc.", version: "2.0.5",
              summary: "Dark-mode any website automatically.",
              detail: "DarkPages injects per-domain CSS inversion + contrast curves so every site reads naturally in dark mode. Per-site overrides via toolbar popup.",
              iconTintHex: 0x8c73d9, iconGlyph: "D",
              permissions: ["Read and modify webpage content"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: nil, rating: nil, ratingCount: nil, category: "Customization"),
    ]

    static let storeCatalog: [BrowserExtension] = [
        .init(id: "store.zoteroconnect",
              name: "Zotero Connector", author: "Corporation for Digital Scholarship", version: "5.0.119",
              summary: "Save references from any web page directly to Zotero.",
              detail: "The Zotero Connector automatically senses content as you browse and lets you save it to Zotero with a single click. Recognizes journal articles, news, books, and more.",
              iconTintHex: 0xc44d4d, iconGlyph: "Z",
              permissions: ["Read webpage content", "Communicate with the Zotero desktop app"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 0, rating: 4.7, ratingCount: 2418, category: "Productivity"),
        .init(id: "store.grammar",
              name: "Grammarly", author: "Grammarly, Inc.", version: "8.901",
              summary: "AI writing assistant in every text field.",
              detail: "Get clear, mistake-free writing in every page's text fields. Grammar, tone, clarity, conciseness.",
              iconTintHex: 0x4b9b41, iconGlyph: "G",
              permissions: ["Read and write to any text field"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 0, rating: 4.5, ratingCount: 18943, category: "Productivity"),
        .init(id: "store.1password",
              name: "1Password", author: "AgileBits Inc.", version: "8.10.30",
              summary: "Autofill passwords, addresses, and credit cards.",
              detail: "1Password is the world's most-loved password manager. Sign in to any site with a single click; everything is end-to-end encrypted.",
              iconTintHex: 0x2c64d0, iconGlyph: "1",
              permissions: ["Read forms on visited sites", "Access form fields"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 0, rating: 4.6, ratingCount: 9821, category: "Privacy"),
        .init(id: "store.pinterest",
              name: "Save to Pinterest", author: "Pinterest", version: "4.5.2",
              summary: "Save any image or page to a Pinterest board.",
              detail: "Hover over any image on the web and click the Save button to save it to a board. Save websites too.",
              iconTintHex: 0xe60023, iconGlyph: "P",
              permissions: ["Read images on visited sites"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: false,
              price: 0, rating: 4.2, ratingCount: 4128, category: "Customization"),
        .init(id: "store.colorpicker",
              name: "ColorPick Eyedropper", author: "Bjoern Schwarzer", version: "1.2.3",
              summary: "Pick any color from any page.",
              detail: "Activate the eyedropper, hover over the page, see the hex/RGB/HSL value and copy with a click. Developer-favorite.",
              iconTintHex: 0xd4af37, iconGlyph: "C",
              permissions: ["Read pixel data from pages"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: false,
              price: 0, rating: 4.4, ratingCount: 832, category: "Developer Tools"),
        .init(id: "store.tabsuspender",
              name: "Tab Snooze", author: "Sleepy Tabs", version: "2.3.0",
              summary: "Snooze tabs and have them reopen when you need them.",
              detail: "Tab Snooze lets you tuck tabs away with one click, scheduled to reappear at a chosen time. Great for inbox-zero browsing.",
              iconTintHex: 0x6b9bd1, iconGlyph: "T",
              permissions: ["Manage tabs", "Access bookmarks"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 2.99, rating: 4.6, ratingCount: 412, category: "Productivity"),
        .init(id: "store.vimari",
              name: "Vimari", author: "Vimari Open Source", version: "3.4.1",
              summary: "Vim-style keyboard shortcuts for browsing.",
              detail: "Hit f to highlight every link with a letter code, then type those letters to follow it — no mouse required. Vimari brings Vim's modal keyboard model to web browsing.",
              iconTintHex: 0x2c8b53, iconGlyph: "V",
              permissions: ["Read and modify webpage content"],
              isEnabled: false, hasToolbarButton: false, hasOptionsPage: true,
              price: 0, rating: 4.8, ratingCount: 1840, category: "Developer Tools"),
        .init(id: "store.privacyguard",
              name: "Privacy Guard", author: "BlueOwl", version: "1.9.4",
              summary: "Block trackers and fingerprinting scripts.",
              detail: "Privacy Guard pairs Safari's built-in tracking prevention with curated lists targeting fingerprint, beacon, and cross-site scripts. Reports impact per site.",
              iconTintHex: 0x4a6cb8, iconGlyph: "P",
              permissions: ["Read webpage content", "Access browsing data"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 0, rating: 4.7, ratingCount: 9112, category: "Privacy"),
        .init(id: "store.bionic",
              name: "Bionic Reader", author: "Saccade", version: "1.1.0",
              summary: "Read faster with assisted text emphasis.",
              detail: "Bolds the first few letters of each word — your eyes complete the rest faster. Per-site toggle and adjustable emphasis weight.",
              iconTintHex: 0x9a4cd6, iconGlyph: "B",
              permissions: ["Read and modify webpage content"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: true,
              price: 1.99, rating: 4.4, ratingCount: 218, category: "Accessibility"),
        .init(id: "store.regex",
              name: "Regex Tester", author: "DevTools Coop", version: "2.2.0",
              summary: "Live regex tester accessible from anywhere.",
              detail: "Test regular expressions against scratchpad text with capture groups, replace, and benchmark modes.",
              iconTintHex: 0xff8c00, iconGlyph: "R",
              permissions: ["No website access"],
              isEnabled: false, hasToolbarButton: true, hasOptionsPage: false,
              price: 0, rating: 4.5, ratingCount: 642, category: "Developer Tools"),
    ]

    /// Distinct categories sourced from the live store catalog — used by the Discover
    /// filter chip strip. "All" is prepended as the default.
    static var storeCategories: [String] {
        ["All"] + Array(Set(storeCatalog.compactMap(\.category))).sorted()
    }
}
