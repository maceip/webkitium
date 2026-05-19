import Foundation

enum PinnedEnginePaths {
    static var embeddedFrameworksInBundle: Bool {
        let base = Bundle.main.privateFrameworksURL
            ?? Bundle.main.bundleURL.appendingPathComponent("Frameworks")
        return FileManager.default.fileExists(atPath: base.appendingPathComponent("WebKit.framework").path)
    }

    static var inProcessEmbedAvailable: Bool {
        embeddedFrameworksInBundle
    }
}
