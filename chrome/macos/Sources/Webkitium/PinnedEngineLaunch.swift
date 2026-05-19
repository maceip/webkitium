import AppKit
import Foundation

/// Launches the pinned WebKit **MiniBrowser** binary from the engine build.
/// No `WKWebView` / system WebKit in this process.
enum PinnedEngineLaunch {
    static func minibrowserPath() -> String? {
        if let p = ProcessInfo.processInfo.environment["WEBKIT_MINIBROWSER"], !p.isEmpty {
            return p
        }
        if let bundle = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("engine/MiniBrowser.app/Contents/MacOS/MiniBrowser"),
           FileManager.default.isExecutableFile(atPath: bundle.path) {
            return bundle.path
        }
        return nil
    }

    static func open(url: String) {
        guard let path = minibrowserPath() else {
            fputs("[webkitium] WEBKIT_MINIBROWSER unset and no engine/MiniBrowser.app beside chrome bundle\n", stderr)
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = [url]
        do {
            try proc.run()
        } catch {
            fputs("[webkitium] MiniBrowser launch failed: \(error)\n", stderr)
        }
    }
}
