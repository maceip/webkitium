import Foundation

/// Remote-store transport for the integrated Extension Store. The four verbs:
/// list / get / query / publish. The mocked impl returns from local data with a small
/// artificial latency; in production this is a gRPC/p2p client behind the same protocol.
protocol ExtensionStoreClient: Sendable {
    func listFeatured() async -> [BrowserExtension]
    func topCharts(category: String?, limit: Int) async -> [BrowserExtension]
    func search(query: String) async -> [BrowserExtension]
    func detail(id: String) async -> BrowserExtension?
    func install(_ ext: BrowserExtension) async -> Bool
}

actor MockExtensionStoreClient: ExtensionStoreClient {
    static let shared = MockExtensionStoreClient()
    private let catalog: [BrowserExtension] = ExtensionCatalog.storeCatalog
    private let latencyNs: UInt64 = 120_000_000

    func listFeatured() async -> [BrowserExtension] {
        try? await Task.sleep(nanoseconds: latencyNs)
        return catalog.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }.prefix(6).map { $0 }
    }

    func topCharts(category: String?, limit: Int) async -> [BrowserExtension] {
        try? await Task.sleep(nanoseconds: latencyNs)
        let pool = catalog.filter { category == nil || $0.category == category }
        return pool.sorted { ($0.ratingCount ?? 0) > ($1.ratingCount ?? 0) }.prefix(limit).map { $0 }
    }

    func search(query: String) async -> [BrowserExtension] {
        try? await Task.sleep(nanoseconds: latencyNs)
        let q = query.lowercased()
        return catalog.filter {
            $0.name.lowercased().contains(q) || $0.summary.lowercased().contains(q)
        }
    }

    func detail(id: String) async -> BrowserExtension? {
        try? await Task.sleep(nanoseconds: latencyNs)
        return catalog.first { $0.id == id }
    }

    func install(_ ext: BrowserExtension) async -> Bool {
        try? await Task.sleep(nanoseconds: latencyNs)
        return true
    }
}
