import Foundation
import WebkitiumSuggestionsC

@MainActor
final class FFIDownloadsManager {
    private nonisolated(unsafe) let handle: OpaquePointer?
    private weak var browser: BrowserViewModel?

    init(dbPath: String?, browser: BrowserViewModel) {
        let cPath = dbPath ?? ""
        self.handle = cPath.withCString { wk_suggestions_open($0) }
        self.browser = browser
    }

    deinit { if let h = handle { wk_suggestions_close(h) } }

    func refreshSnapshot() {
        guard let h = handle, let browser else { return }
        var list = WkDownloadList(downloads: nil, count: 0, _opaque: nil)
        guard wk_downloads_list(h, 64, &list) == 1 else { return }
        defer { wk_downloads_release(&list) }

        browser.downloads = (0..<Int(list.count)).map { i in
            let d = list.downloads![i]
            let filename = d.filename.map(String.init(cString:)) ?? ""
            let totalBytes = d.bytes_total
            let receivedBytes = d.bytes_received
            let progress: Double = totalBytes > 0
                ? min(1.0, max(0.0, Double(receivedBytes) / Double(totalBytes)))
                : (d.completed_ms > 0 ? 1.0 : 0.0)
            return DownloadItem(
                filename: filename,
                sizeText: Self.formatSize(totalBytes),
                progress: progress
            )
        }
    }

    private static func formatSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "" }
        let fmt = ByteCountFormatter()
        fmt.allowedUnits = [.useKB, .useMB, .useGB]
        fmt.countStyle = .file
        return fmt.string(fromByteCount: bytes)
    }
}
