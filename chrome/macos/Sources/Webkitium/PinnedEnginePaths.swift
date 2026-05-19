import Foundation

/// Locates the pinned WebKit build (not system `/System/Library/Frameworks`).
enum PinnedEnginePaths {
    /// When set, `DYLD_FRAMEWORK_PATH` / `-F` should point at `WebKitBuild/Debug`.
    static var frameworkSearchPath: String? {
        if let raw = ProcessInfo.processInfo.environment["WEBKIT_FRAMEWORK_PATH"]?
            .split(separator: ":")
            .map(String.init)
            .first(where: { !$0.isEmpty }) {
            return raw
        }
        let exe = Bundle.main.bundleURL
        let candidates = [
            exe.deletingLastPathComponent().appendingPathComponent("engine"),
            exe.deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("engine"),
        ]
        for base in candidates {
            let fw = base.appendingPathComponent("WebKit.framework")
            if FileManager.default.fileExists(atPath: fw.path) {
                return base.path
            }
        }
        return nil
    }

    static var inProcessEmbedAvailable: Bool {
        guard let root = frameworkSearchPath else { return false }
        return FileManager.default.fileExists(atPath: "\(root)/WebKit.framework")
    }
}
