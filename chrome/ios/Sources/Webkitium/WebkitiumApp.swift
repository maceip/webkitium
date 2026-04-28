import SwiftUI

@main
struct WebkitiumApp: App {
    @StateObject private var browserState = BrowserState()

    var body: some Scene {
        WindowGroup {
            BrowserView()
                .environmentObject(browserState)
        }
    }
}
