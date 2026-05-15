import SwiftUI

/// Standalone Passkey Manager window. Two faces:
///   1. The system passkey **sign-in prompt** — the small centered sheet that appears
///      when a site requests WebAuthn assertion. Site favicon, "Sign in to {site}" header,
///      "Continue with Touch ID" primary action, "Other Options…" link. Mirrors Apple's
///      passkey UI on macOS Sonoma+/Sequoia/Tahoe.
///   2. The **manager list** — a sidebar of saved passkeys (mirroring the Passwords.app
///      style on Sequoia+), with a detail pane showing created/last-used dates and
///      Edit / Delete actions.
struct PasskeyManagerView: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var face: Face = .prompt
    @State private var selectedID: UUID?

    enum Face: Hashable { case prompt, manager }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                switch face {
                case .prompt:  PasskeyPromptSheet()
                case .manager: PasskeyManagerList(selectedID: $selectedID)
                }
            }
        }
        .frame(width: 760, height: 540)
        .onAppear { selectedID = browser.savedPasskeys.first?.id }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Passkeys")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Picker("", selection: $face) {
                Text("Sign-In Prompt").tag(Face.prompt)
                Text("Manage").tag(Face.manager)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Sign-in prompt sheet

/// Mirrors Apple's WebAuthn sign-in sheet: small centered card with site favicon, bold
/// "Sign in to {site}" headline (left-aligned per macOS 26 dialog conventions), body
/// text describing the passkey, blue Continue + Other Options link.
private struct PasskeyPromptSheet: View {
    @Environment(BrowserViewModel.self) private var browser
    @State private var touchIDPulse = false

    var body: some View {
        let site = browser.selectedTab.flatMap { $0.title } ?? "apple.com"
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                browser.selectedTab?.favicon.view(size: 36)
                    ?? BrandFavicon.apple.view(size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sign in to \(site)")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Use a passkey saved in iCloud Keychain")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Passkey for")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(browser.savedPasskeys.first?.username ?? "ryan@icloud.com")
                    .font(.system(size: 13, weight: .medium))
            }

            HStack(spacing: 10) {
                touchIDIndicator
                Text("Touch ID")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack {
                Button("Other Options…") { }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Button("Cancel") { }
                Button("Continue") { }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(22)
        .frame(width: 380)
        .background(.regularMaterial,
                     in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .onAppear { touchIDPulse = true }
    }

    private var touchIDIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.pink.opacity(touchIDPulse ? 0.18 : 0.08))
                .frame(width: 28, height: 28)
                .animation(.smooth(duration: 1.1).repeatForever(autoreverses: true), value: touchIDPulse)
            Image(systemName: "touchid")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.pink)
        }
    }
}

// MARK: - Manager list

private struct PasskeyManagerList: View {
    @Environment(BrowserViewModel.self) private var browser
    @Binding var selectedID: UUID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach(browser.savedPasskeys) { pk in
                    HStack(spacing: 10) {
                        pk.favicon.view(size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(pk.site).font(.system(size: 12, weight: .medium))
                            Text(pk.username)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .tag(pk.id as UUID?)
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 320)
            .listStyle(.sidebar)
        } detail: {
            if let pk = browser.savedPasskeys.first(where: { $0.id == selectedID }) {
                PasskeyDetailPane(passkey: pk)
            } else {
                Text("Select a passkey")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct PasskeyDetailPane: View {
    let passkey: SavedPasskey

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    passkey.favicon.view(size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(passkey.site).font(.title3.weight(.semibold))
                        Text(passkey.username).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                metaRow("Created",   value: dateText(passkey.createdAt))
                metaRow("Last Used", value: dateText(passkey.lastUsedAt))
                metaRow("Stored In", value: "iCloud Keychain")
                metaRow("Synced To", value: "Mac, iPhone")

                Spacer(minLength: 18)
                HStack {
                    Button("Delete Passkey") { }
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Edit Username…") { }
                }
            }
            .padding(24)
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private func metaRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value).font(.system(size: 13))
        }
    }

    private func dateText(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}
