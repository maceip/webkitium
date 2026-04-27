/// CI-only entry point that replaces the SwiftUI @main App with a pure
/// AppKit NSWindow hosting the SwiftUI RootView.  This works around
/// SwiftUI Window scenes not opening on headless EC2 Mac runners.
import Cocoa
import SwiftUI

// We re-use RootView, PaletteProvider, BrowserState, etc. from the main target.
// This file is compiled INTO the same target, replacing WebkitiumApp.swift.

let app = NSApplication.shared
app.setActivationPolicy(.regular)

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let palette = PaletteProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
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

let delegate = AppDelegate()
app.delegate = delegate
app.run()
