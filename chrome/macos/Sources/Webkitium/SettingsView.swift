import SwiftUI

enum SettingsTarget: String, Hashable {
    case extensions, extensionsStore
}

enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general    = "General"
    case tabs       = "Tabs"
    case autofill   = "AutoFill"
    case passwords  = "Passwords"
    case search     = "Search"
    case security   = "Security"
    case privacy    = "Privacy"
    case websites   = "Websites"
    case profiles   = "Profiles"
    case extensions = "Extensions"
    case advanced   = "Advanced"
    case developer  = "Developer"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general:    "gearshape"
        case .tabs:       "rectangle.stack"
        case .autofill:   "rectangle.and.pencil.and.ellipsis"
        case .passwords:  "key.fill"
        case .search:     "magnifyingglass"
        case .security:   "lock.shield"
        case .privacy:    "hand.raised"
        case .websites:   "globe"
        case .profiles:   "person.crop.square.stack"
        case .extensions: "puzzlepiece.extension"
        case .advanced:   "slider.horizontal.3"
        case .developer:  "hammer"
        }
    }
}

/// Settings window — sidebar-driven navigation matching macOS Sonoma+ / Safari 26.
/// Listens for `openSettingsTarget` notifications so the address-bar popover can
/// deep-link to Settings → Extensions → Discover.
struct SettingsView: View {
    let initialTarget: SettingsTarget?
    @State private var selection: SettingsPane = .general
    @State private var extensionsSubsection: ExtensionsPaneView.Mode = .installed

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.rawValue, systemImage: pane.symbol)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 240)
            .listStyle(.sidebar)
        } detail: {
            switch selection {
            case .extensions:
                ExtensionsPaneView(mode: $extensionsSubsection)
            case .passwords:
                PasswordsPaneView()
            default:
                PlaceholderSettingsPane(pane: selection)
            }
        }
        .navigationTitle(selection.rawValue)
        .onAppear { applyTarget(initialTarget) }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTarget)) { note in
            guard let t = note.userInfo?["target"] as? SettingsTarget else { return }
            applyTarget(t)
        }
    }

    private func applyTarget(_ t: SettingsTarget?) {
        guard let t else { return }
        switch t {
        case .extensions:      selection = .extensions; extensionsSubsection = .installed
        case .extensionsStore: selection = .extensions; extensionsSubsection = .discover
        }
    }
}

/// Passwords pane — also surfaces the "Manage Passkeys…" entry to the dedicated window.
/// Matches Safari's pattern of grouping autofill credentials and passkey records in the
/// same settings location.
private struct PasswordsPaneView: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Form {
            Section {
                LabeledContent("AutoFill User Names and Passwords") {
                    Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch)
                }
                LabeledContent("Detect Compromised Passwords") {
                    Toggle("", isOn: .constant(true)).labelsHidden().toggleStyle(.switch)
                }
            }
            Section("Passkeys") {
                Text("Passkeys let you sign in to websites with Touch ID instead of a password.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Manage Passkeys…") { openWindow(id: "passkeys") }
            }
        }
        .formStyle(.grouped)
    }
}

private struct PlaceholderSettingsPane: View {
    let pane: SettingsPane
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: pane.symbol)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            Text(pane.rawValue)
                .font(.title2.weight(.semibold))
            Text("Settings for \(pane.rawValue) will appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
