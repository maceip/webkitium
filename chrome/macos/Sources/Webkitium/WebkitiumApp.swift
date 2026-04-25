// Webkitium macOS shell — entry point.

import SwiftUI

@main
struct WebkitiumApp: App {
    // Single process-global palette provider. Initialized to the shipped
    // default seed; the dev-only cycling shortcut (and, later, the
    // browser.theme extension API host) mutates its seed to push new
    // palettes to all views.
    @StateObject private var palette = PaletteProvider()

    // Wired-but-inactive: ExtensionRegistry, sync stub, and
    // WebAuthnController are constructed at startup.  Settings pages
    // can read counts/state from this object once they bind it; no
    // surface invokes the controllers yet.
    private let services: BrowserServices? = BrowserServices()

    var body: some Scene {
        Window("Webkitium", id: "main") {
            RootView()
                .environmentObject(palette)
                .frame(minWidth: 720, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // Dev-only: ⌘⇧T cycles seeds. Removed when Settings →
            // Appearance → Theme lands.
            CommandMenu("Develop") {
                Button("Cycle Theme Seed") { palette.cycleDevSeed() }
                    .keyboardShortcut("t", modifiers: [.command, .shift])
            }
        }
    }
}
