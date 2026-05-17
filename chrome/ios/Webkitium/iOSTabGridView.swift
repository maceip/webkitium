import SwiftUI

/// Full-screen tab grid presented from the ⋯ → Open Tabs row. Each tab is a
/// rounded card with title, URL, and a close X. Tap to switch; long-press
/// surfaces a context menu (close, duplicate, pin).
struct iOSTabGridView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(browser.tabs) { tab in
                        tabCard(tab)
                    }
                }
                .padding(16)
            }
            .navigationTitle("\(browser.tabs.count) Tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        browser.newTab()
                        dismiss()
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private func tabCard(_ tab: Tab) -> some View {
        let isSelected = tab.id == browser.selectedTabID
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                tab.favicon.view(size: 14)
                Text(tab.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button(action: { browser.close(tab: tab) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemBackground))
                .frame(height: 160)
                .overlay(
                    Text(tab.url.isEmpty ? "—" : tab.url)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(8),
                    alignment: .topLeading)
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .onTapGesture {
            browser.select(tab: tab)
            dismiss()
        }
        .contextMenu {
            Button("Duplicate", systemImage: "plus.square.on.square") {
                browser.duplicate(tab)
            }
            Button(tab.isPinned ? "Unpin" : "Pin",
                    systemImage: tab.isPinned ? "pin.slash" : "pin") {
                browser.togglePin(tab)
            }
            Button("Close Other Tabs", systemImage: "xmark.square") {
                browser.closeOthers(keeping: tab)
            }
            Divider()
            Button("Close Tab", systemImage: "xmark", role: .destructive) {
                browser.close(tab: tab)
            }
        }
    }
}
