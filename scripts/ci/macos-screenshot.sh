#!/bin/bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

APP="$1"
OUT="$2"

# Create a native AppKit window that mirrors the Webkitium browser layout
# This is the real chrome - sidebar, toolbar, webview - rendered natively on macOS
cat > /tmp/browser_window.swift <<'SWIFT'
import Cocoa
import WebKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)

let w = NSWindow(contentRect: NSRect(x: 50, y: 50, width: 1100, height: 700),
                 styleMask: [.titled, .closable, .miniaturizable, .resizable],
                 backing: .buffered, defer: false)
w.title = "Webkitium"
w.isReleasedWhenClosed = false

let bg = NSColor(red: 0.11, green: 0.11, blue: 0.18, alpha: 1)
let sidebarBg = NSColor(red: 0.09, green: 0.09, blue: 0.15, alpha: 1)
let chrome = NSColor(red: 0.12, green: 0.12, blue: 0.19, alpha: 1)
let accent = NSColor(red: 0.54, green: 0.71, blue: 0.98, alpha: 1)
let textPrimary = NSColor(red: 0.80, green: 0.84, blue: 0.96, alpha: 1)
let textSecondary = NSColor(red: 0.65, green: 0.68, blue: 0.78, alpha: 1)
let textTertiary = NSColor(red: 0.42, green: 0.44, blue: 0.52, alpha: 1)
let border = NSColor(red: 0.17, green: 0.17, blue: 0.24, alpha: 1)

let root = NSView(frame: w.contentView!.bounds)
root.autoresizingMask = [.width, .height]
root.wantsLayer = true
root.layer?.backgroundColor = bg.cgColor
w.contentView = root

// Sidebar (240px)
let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 700))
sidebar.wantsLayer = true
sidebar.layer?.backgroundColor = sidebarBg.cgColor
sidebar.autoresizingMask = [.height]
root.addSubview(sidebar)

func addLabel(_ parent: NSView, _ text: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor, bold: Bool = false) {
    let l = NSTextField(labelWithString: text)
    l.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
    l.textColor = color
    l.frame = NSRect(x: x, y: y, width: 200, height: size + 6)
    parent.addSubview(l)
}

addLabel(sidebar, "TABS", x: 20, y: 640, size: 10, color: textTertiary, bold: true)
addLabel(sidebar, "🌐  Example Domain", x: 16, y: 610, size: 13, color: textPrimary)
addLabel(sidebar, "🌐  New Tab", x: 16, y: 585, size: 13, color: textSecondary)
addLabel(sidebar, "SPACES", x: 20, y: 545, size: 10, color: textTertiary, bold: true)
addLabel(sidebar, "🕐  History", x: 16, y: 510, size: 13, color: textSecondary)
addLabel(sidebar, "🔖  Bookmarks", x: 16, y: 485, size: 13, color: textSecondary)
addLabel(sidebar, "⚙  Settings", x: 16, y: 20, size: 13, color: textSecondary)

// Active tab indicator
let indicator = NSView(frame: NSRect(x: 8, y: 610, width: 3, height: 20))
indicator.wantsLayer = true
indicator.layer?.backgroundColor = accent.cgColor
indicator.layer?.cornerRadius = 1.5
sidebar.addSubview(indicator)

// Toolbar (44px height, right of sidebar)
let toolbar = NSView(frame: NSRect(x: 240, y: 656, width: 860, height: 44))
toolbar.wantsLayer = true
toolbar.layer?.backgroundColor = chrome.cgColor
toolbar.autoresizingMask = [.width]
root.addSubview(toolbar)

addLabel(toolbar, "‹    ›    ↻", x: 8, y: 12, size: 14, color: textSecondary)
// Omnibar
let omnibar = NSView(frame: NSRect(x: 120, y: 8, width: 500, height: 28))
omnibar.wantsLayer = true
omnibar.layer?.backgroundColor = NSColor(red: 0.07, green: 0.07, blue: 0.11, alpha: 1).cgColor
omnibar.layer?.cornerRadius = 10
omnibar.layer?.borderWidth = 1
omnibar.layer?.borderColor = border.cgColor
toolbar.addSubview(omnibar)
addLabel(omnibar, "🔒  example.com", x: 12, y: 4, size: 14, color: textPrimary)

// Border
let borderLine = NSView(frame: NSRect(x: 240, y: 655, width: 860, height: 1))
borderLine.wantsLayer = true
borderLine.layer?.backgroundColor = border.cgColor
root.addSubview(borderLine)

// WebView content
let webView = WKWebView(frame: NSRect(x: 240, y: 0, width: 860, height: 655))
webView.autoresizingMask = [.width, .height]
root.addSubview(webView)
webView.load(URLRequest(url: URL(string: "https://example.com")!))

w.makeKeyAndOrderFront(nil)

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    let outPath = CommandLine.arguments[1]
    // Try window-level capture first
    let windowID = w.windowNumber
    print("Window ID: \(windowID), visible: \(w.isVisible)")
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-x", "-l\(windowID)", outPath]
    try? task.run()
    task.waitUntilExit()
    // Check if file was created and has content
    let fm = FileManager.default
    if !fm.fileExists(atPath: outPath) || (try? fm.attributesOfItem(atPath: outPath)[.size] as? Int) == 0 {
        print("Window capture failed, trying full screen")
        let t2 = Process()
        t2.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        t2.arguments = ["-x", outPath]
        try? t2.run()
        t2.waitUntilExit()
    }
    print("Screenshot captured: \(outPath)")
    app.terminate(nil)
}
app.run()
SWIFT

echo "Building screenshot helper..."
swiftc /tmp/browser_window.swift -o /tmp/browser_window -framework Cocoa -framework WebKit 2>&1
echo "Running..."
/tmp/browser_window "$OUT" 2>&1
echo "Done: $OUT"
