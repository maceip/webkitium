import SwiftUI

/// Settings → Extensions pane. Top segmented control toggles between Installed and the
/// integrated Discover (Store) view. Mirrors the AppKit version's structure exactly.
struct ExtensionsPaneView: View {
    enum Mode: Int, CaseIterable, Identifiable {
        case installed, discover
        var id: Int { rawValue }
        var title: String { self == .installed ? "Installed" : "Discover" }
    }

    @Binding var mode: Mode

    var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)
            .padding(.top, 12)

            switch mode {
            case .installed: InstalledExtensionsView()
            case .discover:  ExtensionStoreView()
            }
        }
    }
}

// MARK: - Installed list

private struct InstalledExtensionsView: View {
    @State private var extensions = ExtensionCatalog.installed
    @State private var selectedID: String? = ExtensionCatalog.installed.first?.id

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedID) {
                ForEach($extensions) { $ext in
                    HStack(spacing: 8) {
                        ExtensionIcon(ext: ext, size: 28)
                        Text(ext.name).font(.system(size: 13))
                        Spacer(minLength: 0)
                        Toggle("", isOn: $ext.isEnabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .labelsHidden()
                    }
                    .tag(ext.id as String?)
                }
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
            .listStyle(.sidebar)
        } detail: {
            if let selected = extensions.first(where: { $0.id == selectedID }) {
                ExtensionDetailView(ext: selected)
            } else {
                Text("Select an extension")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ExtensionDetailView: View {
    let ext: BrowserExtension
    @State private var allowPrivateBrowsing = false
    @State private var websitesMode = "Ask"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    ExtensionIcon(ext: ext, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ext.name).font(.title3.weight(.semibold))
                        Text("Version \(ext.version)")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("by \(ext.author)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Text(ext.detail).font(.system(size: 13))
                Toggle("Allow in Private Browsing", isOn: $allowPrivateBrowsing)
                Text("Permissions").font(.system(size: 13, weight: .semibold))
                ForEach(ext.permissions, id: \.self) { perm in
                    HStack(spacing: 6) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 5))
                            .foregroundStyle(.secondary)
                        Text(perm).font(.system(size: 12))
                    }
                }
                Text("Websites").font(.system(size: 13, weight: .semibold))
                HStack {
                    Picker("Websites", selection: $websitesMode) {
                        Text("Ask").tag("Ask")
                        Text("Deny").tag("Deny")
                        Text("Allow").tag("Allow")
                    }
                    .labelsHidden()
                    Button("Edit Websites…") { }
                    Spacer()
                }
                Spacer(minLength: 24)
                HStack {
                    Button("Uninstall") { }
                        .foregroundStyle(.red)
                    Spacer()
                    Button("Open in App Store") { }
                }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }
}

// MARK: - Discover (Store)

private struct ExtensionStoreView: View {
    private let client: any ExtensionStoreClient = MockExtensionStoreClient.shared
    @State private var search = ""
    @State private var category = "All"
    @State private var featured: [BrowserExtension] = []
    @State private var topCharts: [BrowserExtension] = []
    @State private var searchResults: [BrowserExtension] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search extensions", text: $search)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .onChange(of: search) { _, newValue in
                Task { searchResults = await client.search(query: newValue) }
            }

            categoryStrip

            ScrollView {
                if search.isEmpty {
                    homeContent
                } else {
                    searchContent
                }
            }
        }
        .task { await load() }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(ExtensionCatalog.storeCategories, id: \.self) { cat in
                    Button { category = cat } label: {
                        Text(cat)
                            .font(.system(size: 11, weight: category == cat ? .semibold : .regular))
                            .foregroundStyle(category == cat ? .white : .primary)
                            .padding(.horizontal, 10)
                            .frame(height: 22)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(category == cat ? Color.accentColor :
                                          Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.top, 8)
    }

    private func load() async {
        featured = await client.listFeatured()
        topCharts = await client.topCharts(category: nil, limit: 12)
    }

    private var filteredFeatured: [BrowserExtension] {
        category == "All" ? featured : featured.filter { $0.category == category }
    }
    private var filteredTopCharts: [BrowserExtension] {
        category == "All" ? topCharts : topCharts.filter { $0.category == category }
    }

    @ViewBuilder
    private var homeContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let hero = filteredFeatured.first { HeroCard(ext: hero) }
            Text("Editor's Picks").font(.title3.weight(.bold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(filteredFeatured) { StoreCard(ext: $0) }
                }
            }
            Text("Top Charts").font(.title3.weight(.bold))
            VStack(spacing: 0) {
                let chart = filteredTopCharts
                ForEach(Array(chart.enumerated()), id: \.element.id) { idx, ext in
                    TopChartRow(rank: idx + 1, ext: ext)
                    if idx < chart.count - 1 { Divider() }
                }
            }
        }
        .padding(24)
    }

    @ViewBuilder
    private var searchContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results for \"\(search)\"").font(.title3.weight(.bold))
            if searchResults.isEmpty {
                Text("No results.").foregroundStyle(.secondary)
            } else {
                ForEach(searchResults) { SearchResultRow(ext: $0) }
            }
        }
        .padding(24)
    }
}

private struct HeroCard: View {
    let ext: BrowserExtension
    var body: some View {
        HStack(spacing: 18) {
            ExtensionIcon(ext: ext, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text("FEATURED")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(ext.name).font(.title.weight(.bold))
                Text(ext.summary).font(.system(size: 13)).foregroundStyle(.secondary)
                InstallButton(ext: ext)
            }
            Spacer()
        }
        .padding(18)
        .frame(height: 132)
        .background(
            Color.accentColor.opacity(0.15),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct StoreCard: View {
    let ext: BrowserExtension
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ExtensionIcon(ext: ext, size: 32)
                Text(ext.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            Text(ext.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            HStack {
                if let rating = ext.rating {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", rating))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                InstallButton(ext: ext)
            }
        }
        .padding(10)
        .frame(width: 220, height: 120)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.separator, lineWidth: 1)
        )
    }
}

private struct TopChartRow: View {
    let rank: Int
    let ext: BrowserExtension
    var body: some View {
        HStack(spacing: 14) {
            Text("\(rank)")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .trailing)
            ExtensionIcon(ext: ext, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(ext.name).font(.system(size: 13, weight: .semibold))
                Text(ext.category ?? "").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            InstallButton(ext: ext)
        }
        .padding(.vertical, 6)
    }
}

private struct SearchResultRow: View {
    let ext: BrowserExtension
    var body: some View {
        HStack(spacing: 12) {
            ExtensionIcon(ext: ext, size: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text(ext.name).font(.system(size: 13, weight: .semibold))
                Text(ext.summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            InstallButton(ext: ext)
        }
        .padding(.vertical, 4)
    }
}

private struct InstallButton: View {
    let ext: BrowserExtension
    @State private var state: ButtonState = .available
    private enum ButtonState { case available, installing, installed }

    var body: some View {
        Button(action: install) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(minWidth: 56)
        }
        .disabled(state == .installing)
    }

    private var label: String {
        switch state {
        case .available:  return ext.price.map { String(format: "$%.2f", $0) } ?? "GET"
        case .installing: return "Installing…"
        case .installed:  return "OPEN"
        }
    }

    private func install() {
        state = .installing
        Task {
            let ok = await MockExtensionStoreClient.shared.install(ext)
            await MainActor.run { state = ok ? .installed : .available }
        }
    }
}
