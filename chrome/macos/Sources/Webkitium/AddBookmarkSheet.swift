import SwiftUI

/// Compact "Add Bookmark" sheet — the macOS-Safari equivalent of pressing Cmd+D. Pre-fills
/// title and URL from the active tab, lets the user pick a destination folder, and on
/// Save appends a `BookmarkEntry` to the selected folder.
struct AddBookmarkSheet: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var url: String = ""
    @State private var folderID: UUID?

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                (browser.selectedTab?.favicon ?? .generic(symbol: "globe")).view(size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Bookmark")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Choose where to save this page.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Form {
                TextField("Title", text: $title)
                TextField("URL",   text: $url)
                Picker("Folder", selection: $folderID) {
                    ForEach(browser.bookmarkFolders) { folder in
                        Label(folder.name, systemImage: folder.symbol).tag(folder.id as UUID?)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || folderID == nil)
            }
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            title = browser.selectedTab?.title ?? "Page"
            url = browser.selectedTab?.url ?? browser.urlText
            folderID = browser.bookmarkFolders.first?.id
        }
    }

    private func save() {
        guard let id = folderID,
              let folder = browser.bookmarkFolders.first(where: { $0.id == id })
        else { return }
        browser.addBookmark(title: title, url: url, folder: folder)
        dismiss()
    }
}
