import Cocoa

/// Injected into CI builds to force the SwiftUI Window scene to show.
/// SwiftUI on macOS 26 may not auto-open the initial window when launched
/// from a non-interactive shell. This observer forces activation once the
/// app finishes launching.
class ForceWindowOpener: NSObject {
    static let shared = ForceWindowOpener()

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }

    @objc func appDidFinishLaunching(_ note: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            // If SwiftUI created a window but didn't show it, force it
            if let window = NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
                NSLog("ForceWindow: activated existing window")
            } else {
                NSLog("ForceWindow: no windows exist yet, waiting...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NSLog("ForceWindow: retry - windows=\(NSApp.windows.count)")
                }
            }
        }
    }
}

// Force instantiation at module load time
private let _forceWindowInit: Void = {
    _ = ForceWindowOpener.shared
}()
