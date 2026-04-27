import Cocoa
import SwiftUI

@main
struct WebkitiumCI {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)

        let delegate = WebkitiumAppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class WebkitiumAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let palette = PaletteProvider()
        let rootView = RootView()
            .environmentObject(palette)
            .frame(minWidth: 720, minHeight: 480)

        window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1100, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Webkitium"
        window.contentView = NSHostingView(rootView: rootView)
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSLog("WebkitiumCI: window created, visible=\(window.isVisible)")

        // After 8 seconds, capture the window to a file and exit
        // This is the CI screenshot capture mechanism
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self, let view = self.window.contentView else { return }
            let screenshotPath = ProcessInfo.processInfo.environment["WEBKITIUM_SCREENSHOT_PATH"] ?? "/tmp/webkitium_screenshot.png"
            if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    try? data.write(to: URL(fileURLWithPath: screenshotPath))
                    NSLog("WebkitiumCI: captured \(Int(view.bounds.width))x\(Int(view.bounds.height)) to \(screenshotPath)")
                }
            }
            NSApp.terminate(nil)
        }
    }
}
