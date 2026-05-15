import SwiftUI

/// Translation popover — invoked from the URL bar's translation icon. Matches Safari's
/// compact popover: a "Translate from … to …" pair of menus, an Auto-translate toggle,
/// and a "Show Original" button to revert.
struct TranslationPopover: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Translate Page")
                        .font(.system(size: 13, weight: .semibold))
                    Text(browser.selectedTab?.title ?? "this page")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            Divider()

            languagePicker(label: "From", selection: $browserBinding.translationFrom)
            languagePicker(label: "To",   selection: $browserBinding.translationTo)

            Toggle(isOn: $browserBinding.translationAuto) {
                Text("Always Translate \(browser.translationFrom.rawValue)")
                    .font(.system(size: 12))
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            HStack {
                Button("Show Original") { dismiss() }
                Spacer()
                Button("Translate") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private func languagePicker(label: String,
                                 selection: Binding<TranslationLanguage>) -> some View {
        HStack {
            Text(label).font(.system(size: 12)).frame(width: 44, alignment: .leading)
            Picker(label, selection: selection) {
                ForEach(TranslationLanguage.allCases) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity)
        }
    }
}
