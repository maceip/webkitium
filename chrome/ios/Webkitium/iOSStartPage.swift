import SwiftUI

/// Safari iOS 26 Start Page clone. Visible whenever there's no selected tab.
/// "Customize Start Page" pill, favorites grid (4×N tiles with letter avatars),
/// Privacy Report card with shield icon.
struct iOSStartPage: View {
    @Environment(BrowserViewModel.self) private var browser

    /// First-cut: hardcode 4 favorites to match the reference. Real bookmarks
    /// integration comes when the bookmark store's "Favorites" folder is
    /// surfaced here.
    private let favorites: [Favorite] = Array(FavoritesCatalog.all.prefix(4))

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                customizeCard
                    .padding(.top, 16)
                favoritesSection
                privacyReportCard
                Spacer(minLength: 80) // leave room for the bottom URL bar
            }
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var customizeCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Start Page")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.orange.opacity(0.4), .pink.opacity(0.3),
                                                    .green.opacity(0.3)],
                                          startPoint: .leading, endPoint: .trailing))
                    .frame(height: 110)
                HStack(spacing: 8) {
                    miniGridSwatch(label: "Favorites")
                    miniGridSwatch(label: "Suggestions")
                }
            }
            Text("Customize your wallpaper and sections that appear when creating new tabs.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Button(action: {}) {
                Text("Customize Start Page")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground),
                    in: .rect(cornerRadius: 18, style: .continuous))
    }

    private func miniGridSwatch(label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(10), spacing: 3), count: 4),
                       spacing: 3) {
                ForEach(0..<8, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.6))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
    }

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Favorites", systemImage: "person.fill")
                .font(.system(size: 22, weight: .bold))
                .labelStyle(.titleAndIcon)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4),
                       spacing: 16) {
                ForEach(favorites) { fav in
                    Button(action: { browser.navigateActive(to: fav.url) }) {
                        favoriteTile(fav)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func favoriteTile(_ fav: Favorite) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 64, height: 64)
                Text(String(fav.title.prefix(1)))
                    .font(.system(size: 32, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
            }
            Text(fav.title)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    private var privacyReportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Privacy Report")
                .font(.system(size: 22, weight: .bold))
            HStack(spacing: 14) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text("In the last seven days, Webkitium has prevented 0 trackers from profiling you.")
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground),
                        in: .rect(cornerRadius: 16, style: .continuous))
            HStack {
                Spacer()
                Button("Edit") { }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: .capsule)
                Spacer()
            }
            .padding(.top, 6)
        }
    }
}
