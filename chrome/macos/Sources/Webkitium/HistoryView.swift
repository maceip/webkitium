import SwiftUI

/// History sheet (Cmd+Y) — searchable list grouped by Today / Yesterday / Earlier this week.
/// Matches Safari's history surface: a wide sheet with a sticky search field and bucketed
/// rows showing favicon, title, host, and visit time.
struct HistoryView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        guard !query.isEmpty else { return browser.history }
        let q = query.lowercased()
        return browser.history.filter {
            $0.title.lowercased().contains(q) || $0.url.lowercased().contains(q)
        }
    }

    private var grouped: [(HistoryEntry.Bucket, [HistoryEntry])] {
        let buckets = HistoryEntry.Bucket.allCases
        return buckets.compactMap { b in
            let items = filtered.filter { HistoryCatalog.bucket(for: $0.visitedAt) == b }
                                .sorted { $0.visitedAt > $1.visitedAt }
            return items.isEmpty ? nil : (b, items)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if grouped.isEmpty {
                        emptyState
                    } else {
                        ForEach(grouped, id: \.0) { bucket, items in
                            section(title: bucket.title, items: items)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .frame(width: 720, height: 560)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("History")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("Search History", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .frame(width: 240, height: 24)
            .background(.thinMaterial, in: Capsule(style: .continuous))
            Button("Clear History…") { browser.history.removeAll() }
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func section(title: String, items: [HistoryEntry]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.leading, 6)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, entry in
                    HistoryRow(entry: entry)
                    if idx < items.count - 1 { Divider().padding(.leading, 36) }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(query.isEmpty ? "No History" : "No matches for \"\(query)\"")
                .font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 320)
    }
}

private struct HistoryRow: View {
    @Environment(BrowserViewModel.self) private var browser
    let entry: HistoryEntry
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            entry.favicon.view(size: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(entry.url)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(entry.visitedAt, style: .time)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(hovering ? Color.accentColor.opacity(0.14) : .clear)
        .contentShape(Rectangle())
        .onHover { isHovering in
            hovering = isHovering
            browser.hoveredLink = isHovering ? entry.url : nil
        }
    }
}
