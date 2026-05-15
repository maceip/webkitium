import SwiftUI

/// "Settings for This Website" sheet — per-site permissions. Matches Safari's layout:
/// a Form with one row per permission, each row being a leading icon + label + trailing
/// popup menu.
struct SiteSettingsSheet: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            HStack {
                ZStack {
                    Circle().fill(.thinMaterial).frame(width: 32, height: 32)
                    Image(systemName: "globe").font(.system(size: 14))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Settings for")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(siteHost).font(.system(size: 14, weight: .semibold))
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)

            Divider()

            Form {
                ForEach($browserBinding.sitePermissions) { $perm in
                    HStack(spacing: 10) {
                        Image(systemName: perm.symbol)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        Text(perm.title).font(.system(size: 13))
                        Spacer(minLength: 16)
                        Picker("", selection: $perm.current) {
                            ForEach(perm.options, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 520, height: 520)
    }

    private var siteHost: String {
        if let host = URL(string: browser.urlText)?.host { return host }
        return "this website"
    }
}
