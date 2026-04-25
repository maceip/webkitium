import SwiftUI

@main
struct WebkitiumApp: App {
    @StateObject private var palette = PaletteProvider()
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
            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTabCommand, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandMenu("Tab") {
                Button("Close Tab") {
                    NotificationCenter.default.post(name: .closeTabCommand, object: nil)
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Restore Closed Tab") {
                    NotificationCenter.default.post(name: .restoreTabCommand, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            CommandMenu("Navigate") {
                Button("Back") {
                    NotificationCenter.default.post(name: .goBackCommand, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Forward") {
                    NotificationCenter.default.post(name: .goForwardCommand, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Reload") {
                    NotificationCenter.default.post(name: .reloadCommand, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("Find") {
                Button("Find in Page") {
                    NotificationCenter.default.post(name: .findCommand, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .zoomInCommand, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .zoomOutCommand, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Reset Zoom") {
                    NotificationCenter.default.post(name: .zoomResetCommand, object: nil)
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandMenu("Page") {
                Button("Print") {
                    NotificationCenter.default.post(name: .printCommand, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Bookmark This Page") {
                    NotificationCenter.default.post(name: .bookmarkCommand, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)
            }

            CommandMenu("Develop") {
                Button("Cycle Theme Seed") { palette.cycleDevSeed() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
            }
        }
    }
}
