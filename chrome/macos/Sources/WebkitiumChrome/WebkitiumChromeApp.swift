import SwiftUI

@main
struct WebkitiumChromeApp: App {
    var body: some Scene {
        WindowGroup {
            BrowserChromeView()
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTabRequested, object: nil)
                }
                .keyboardShortcut("t", modifiers: [.command])
            }
        }
    }
}

extension Notification.Name {
    static let newTabRequested = Notification.Name("dev.webkitium.chrome.new-tab")
}
