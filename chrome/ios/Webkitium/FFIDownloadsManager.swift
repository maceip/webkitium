import Foundation
@preconcurrency import WebKit
import WebkitiumSuggestionsC

/// iOS variant of the macOS downloads manager. No `~/Downloads` on iOS —
/// destination is the app's Documents directory so files survive across
/// app launches and are visible via the Files app.
@MainActor
final class FFIDownloadsManager: NSObject, WKDownloadDelegate {
    private nonisolated(unsafe) let handle: OpaquePointer?
    private weak var browser: BrowserViewModel?

    private var rowIDs:           [ObjectIdentifier: Int64] = [:]
    /// Bytes expected for each in-flight download (from URLResponse.expectedContentLength).
    /// 0 when the server doesn't advertise a length.
    private var expectedTotals:   [ObjectIdentifier: Int64] = [:]
    /// Cumulative bytes received so far. Separate from `expectedTotals` —
    /// the original kit reused one dict for both, so the first chunk would
    /// compute `received = expected + chunkBytes`.
    private var receivedTotals:   [ObjectIdentifier: Int64] = [:]

    init(dbPath: String?, browser: BrowserViewModel) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
        self.browser = browser
        super.init()
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    func attach(_ download: WKDownload) {
        download.delegate = self
    }

    func refreshSnapshot() {
        guard let h = handle, let browser else { return }
        var list = WkDownloadList(downloads: nil, count: 0, _opaque: nil)
        guard wk_downloads_list(h, 64, &list) == 1 else { return }
        defer { wk_downloads_release(&list) }

        let items: [DownloadItem] = (0..<Int(list.count)).map { i in
            let d = list.downloads![i]
            let filename = d.filename.map(String.init(cString:)) ?? ""
            let totalBytes = d.bytes_total
            let receivedBytes = d.bytes_received
            let progress: Double = totalBytes > 0
                ? min(1.0, max(0.0, Double(receivedBytes) / Double(totalBytes)))
                : (d.completed_ms > 0 ? 1.0 : 0.0)
            return DownloadItem(filename: filename,
                                  sizeText: Self.formatSize(totalBytes),
                                  progress: progress)
        }
        browser.downloads = items
    }

    private static func formatSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useKB, .useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }

    func download(_ download: WKDownload,
                   decideDestinationUsing response: URLResponse,
                   suggestedFilename: String) async -> URL? {
        let dir = FileManager.default.urls(for: .documentDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(suggestedFilename)
        let total = response.expectedContentLength
        if let h = handle {
            let id = suggestedFilename.withCString { fn in
                (response.url?.absoluteString ?? "").withCString { src in
                    url.path.withCString { dst in
                        wk_downloads_start(h, fn, src, dst, total > 0 ? total : 0)
                    }
                }
            }
            // We're already @MainActor-isolated — no need to hop again.
            rowIDs[ObjectIdentifier(download)]         = id
            expectedTotals[ObjectIdentifier(download)] = max(total, 0)
            receivedTotals[ObjectIdentifier(download)] = 0
            refreshSnapshot()
        }
        return url
    }

    func download(_ download: WKDownload, didReceive bytes: Int64) {
        guard let id = rowIDs[ObjectIdentifier(download)], let h = handle else { return }
        let key = ObjectIdentifier(download)
        let received = (receivedTotals[key] ?? 0) + bytes
        receivedTotals[key] = received
        wk_downloads_progress(h, id, received)
        refreshSnapshot()
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let h = handle else { return }
        let key = ObjectIdentifier(download)
        if let id = rowIDs.removeValue(forKey: key) {
            wk_downloads_complete(h, id)
        }
        expectedTotals.removeValue(forKey: key)
        receivedTotals.removeValue(forKey: key)
        refreshSnapshot()
    }

    func download(_ download: WKDownload,
                   didFailWithError error: Error,
                   resumeData: Data?) {
        guard let h = handle else { return }
        let key = ObjectIdentifier(download)
        if let id = rowIDs.removeValue(forKey: key) {
            wk_downloads_cancel(h, id)
        }
        expectedTotals.removeValue(forKey: key)
        receivedTotals.removeValue(forKey: key)
        refreshSnapshot()
    }
}
