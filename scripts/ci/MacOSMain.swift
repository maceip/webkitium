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
    }
}
