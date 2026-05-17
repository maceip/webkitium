import SwiftUI

/// iOS Settings sheet — mirrors the macOS Search pane and adds a small set
/// of toggles. Matches Safari iOS's grouped-form pattern.
struct iOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("Webkitium.SearchEngine") private var rawEngine: String =
        SearchEngine.defaultEngine.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section("Search") {
                    Picker("Search Engine", selection: $rawEngine) {
                        ForEach(SearchEngine.allCases) { engine in
                            Label(engine.displayName, systemImage: engine.faviconSymbol)
                                .tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    Text("Default is DuckDuckGo. Webkitium does not pre-select Google.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Section("Suggestions") {
                    Toggle("Include Search Engine Suggestions", isOn: .constant(true))
                    Toggle("Include History in Suggestions",   isOn: .constant(true))
                    Toggle("Include Bookmarks in Suggestions", isOn: .constant(true))
                }
                Section("Privacy") {
                    Toggle("Prevent Cross-Site Tracking", isOn: .constant(true))
                    Toggle("Block All Cookies",            isOn: .constant(false))
                    Toggle("Strip Tracking Parameters",    isOn: .constant(true))
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
