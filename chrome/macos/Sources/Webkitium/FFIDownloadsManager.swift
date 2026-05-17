import Foundation
@preconcurrency import WebKit
import WebkitiumSuggestionsC

/// Bridge between WKWebView's `WKDownload` callbacks and the unified
/// SQLite store. Each download:
///   1. starts → `wk_downloads_start` returns a rowid; the WKDownload
///      delegate keeps that rowid for later progress / completion calls
///   2. writes destination via the `decideDestinationUsing` callback —
///      we default to `~/Downloads/<suggested-filename>`
///   3. progresses → `wk_downloads_progress`
///   4. finishes → `wk_downloads_complete`; or `wk_downloads_cancel` on
///      failure / user cancel
///
/// The Swift `DownloadItem` array on `BrowserViewModel` is the UI's
/// snapshot; it's refreshed from the FFI store after each lifecycle
/// event. For private windows the manager is constructed with an empty
/// `dbPath` so the underlying SQLite is in-memory.
@MainActor
final class FFIDownloadsManager: NSObject, WKDownloadDelegate {
    private nonisolated(unsafe) let handle: OpaquePointer?
    private weak var browser: BrowserViewModel?

    /// rowid lookup: WKDownload identity → FFI download id. WKDownload is
    /// an NSObject so it's safe to key by ObjectIdentifier.
    private var rowIDs: [ObjectIdentifier: Int64] = [:]
    private var totals: [ObjectIdentifier: Int64] = [:]

    init(dbPath: String?, browser: BrowserViewModel) {
        let cPath = (dbPath ?? "")
        self.handle = cPath.withCString { wk_suggestions_open($0) }
        self.browser = browser
        super.init()
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    /// Called by the WKDownload protocol when a new download starts.
    func attach(_ download: WKDownload) {
        download.delegate = self
    }

    /// Hydrate the BrowserViewModel.downloads array from the persistent
    /// store on launch. Called once per window.
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

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload,
                   decideDestinationUsing response: URLResponse,
                   suggestedFilename: String) async -> URL? {
        let dir = FileManager.default.urls(for: .downloadsDirectory,
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
            await MainActor.run {
                self.rowIDs[ObjectIdentifier(download)] = id
                self.totals[ObjectIdentifier(download)] = max(total, 0)
                self.refreshSnapshot()
            }
        }
        return url
    }

    func download(_ download: WKDownload, didReceive bytes: Int64) {
        guard let id = rowIDs[ObjectIdentifier(download)], let h = handle else { return }
        let received = (totals[ObjectIdentifier(download)] ?? 0) + bytes
        totals[ObjectIdentifier(download)] = received
        wk_downloads_progress(h, id, received)
        refreshSnapshot()
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let h = handle else { return }
        if let id = rowIDs.removeValue(forKey: ObjectIdentifier(download)) {
            wk_downloads_complete(h, id)
        }
        totals.removeValue(forKey: ObjectIdentifier(download))
        refreshSnapshot()
    }

    func download(_ download: WKDownload,
                   didFailWithError error: Error,
                   resumeData: Data?) {
        guard let h = handle else { return }
        if let id = rowIDs.removeValue(forKey: ObjectIdentifier(download)) {
            wk_downloads_cancel(h, id)
        }
        totals.removeValue(forKey: ObjectIdentifier(download))
        refreshSnapshot()
    }
}
