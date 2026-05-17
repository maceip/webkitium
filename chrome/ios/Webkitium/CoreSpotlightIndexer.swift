import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Mirrors history visits and bookmarks into the system-wide Spotlight
/// index, so the user can search the menu bar for a page they once
/// visited. Two domains keep the surfaces distinct and let us clear them
/// independently ("Clear History" wipes the visits domain only).
///
/// Privacy contract: the manager is only constructed for REGULAR (non-
/// private) windows. Private windows never call into it, so private-mode
/// visits never reach CSSearchableIndex.
@MainActor
final class CoreSpotlightIndexer {
    private static let visitsDomain   = "org.webkitium.history"
    private static let bookmarksDomain = "org.webkitium.bookmarks"

    static let shared = CoreSpotlightIndexer()
    private init() {}

    /// Index (or re-index) a single visited URL. Idempotent — repeated
    /// calls update the existing record by identifier (the URL string).
    func indexVisit(title: String, url: String) {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.url)
        attrs.title = title.isEmpty ? url : title
        attrs.contentDescription = url
        attrs.url = URL(string: url)
        let item = CSSearchableItem(uniqueIdentifier: url,
                                      domainIdentifier: Self.visitsDomain,
                                      attributeSet: attrs)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    func indexBookmark(title: String, url: String) {
        let attrs = CSSearchableItemAttributeSet(contentType: UTType.url)
        attrs.title = title.isEmpty ? url : title
        attrs.contentDescription = "Bookmark · \(url)"
        attrs.url = URL(string: url)
        let item = CSSearchableItem(uniqueIdentifier: "bm:\(url)",
                                      domainIdentifier: Self.bookmarksDomain,
                                      attributeSet: attrs)
        CSSearchableIndex.default().indexSearchableItems([item], completionHandler: nil)
    }

    /// Clears both domains. Wired to the "Clear History" action.
    func clearAll() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [Self.visitsDomain, Self.bookmarksDomain],
            completionHandler: nil)
    }
}
