import SwiftUI

/// Toolbar downloads button + popover. Lists recent downloads with progress bars for
/// in-flight items and a "Show in Finder" action for completed ones.
struct DownloadsToolbarButton: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        Button {
            browser.showDownloadsPopover.toggle()
        } label: {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.borderless)
        .help("Show Downloads")
        .popover(isPresented: $browserBinding.showDownloadsPopover, arrowEdge: .bottom) {
            DownloadsPopover().frame(width: 340)
        }
    }
}

struct DownloadsPopover: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Downloads").font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Clear") { browser.downloads.removeAll { $0.isCompleted } }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 6)

            Divider()

            if browser.downloads.isEmpty {
                Text("No recent downloads")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ForEach(browser.downloads) { d in
                    DownloadRow(item: d)
                    Divider().padding(.leading, 44)
                }
            }
        }
        .padding(.bottom, 6)
    }
}

private struct DownloadRow: View {
    @Environment(BrowserViewModel.self) private var browser
    let item: DownloadItem

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.filename)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !item.isCompleted {
                    ProgressView(value: item.progress)
                        .progressViewStyle(.linear)
                        .controlSize(.mini)
                }
                Text(item.sizeText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if item.isCompleted {
                Button { /* show in finder */ } label: {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
            } else {
                Button {
                    browser.downloads.removeAll { $0.id == item.id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Cancel Download")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
