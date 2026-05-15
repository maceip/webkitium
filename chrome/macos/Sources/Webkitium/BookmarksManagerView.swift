import SwiftUI

/// Bookmarks manager (Cmd+Opt+B). Two-column split: folder tree on the left, bookmarks
/// table in the selected folder on the right. Matches Safari's standalone Edit Bookmarks
/// surface — same column layout, hover-action New Folder, context-menu edit/delete.
struct BookmarksManagerView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFolderID: UUID?
    @State private var rowSelection: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            NavigationSplitView {
                List(selection: $selectedFolderID) {
                    ForEach(browser.bookmarkFolders) { folder in
                        Label(folder.name, systemImage: folder.symbol)
                            .tag(folder.id as UUID?)
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
                .listStyle(.sidebar)
            } detail: {
                if let folder = browser.bookmarkFolders.first(where: { $0.id == selectedFolderID }) {
                    BookmarksTable(folder: folder, selection: $rowSelection)
                } else {
                    Text("Select a folder")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationSplitViewStyle(.balanced)
        }
        .frame(width: 820, height: 560)
        .onAppear { selectedFolderID = browser.bookmarkFolders.first?.id }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Bookmarks")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button {
                browser.bookmarkFolders.append(
                    BookmarkFolder(name: "New Folder", symbol: "folder.fill", bookmarks: []))
            } label: { Label("New Folder", systemImage: "folder.badge.plus") }
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct BookmarksTable: View {
    let folder: BookmarkFolder
    @Binding var selection: UUID?

    var body: some View {
        Table(folder.bookmarks, selection: $selection) {
            TableColumn("Title") { item in
                HStack(spacing: 8) {
                    item.favicon.view(size: 14)
                    Text(item.title).font(.system(size: 12))
                }
            }
            .width(min: 200, ideal: 320)
            TableColumn("Address") { item in
                Text(item.url)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            Button("Open in New Tab") { }
            Button("Edit…") { }
            Divider()
            Button("Delete", role: .destructive) { }
        } primaryAction: { _ in /* double-click open */ }
    }
}
