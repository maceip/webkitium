import Foundation

/// iOS cannot spawn the engine binary from the chrome app sandbox.
/// CI bundles `MobileMiniBrowser.app` under `engine/`; wire in-process embed next.
enum PinnedEngineLaunch {
    static func open(url: String) {
        _ = url
        fputs("[webkitium] iOS: navigation recorded; open engine/MobileMiniBrowser.app from the platform bundle (in-process embed pending)\n", stderr)
    }
}
