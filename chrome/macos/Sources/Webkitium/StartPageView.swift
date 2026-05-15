import SwiftUI

/// Start Page content. Three sections, vertically stacked: "Make Safari Default" banner,
/// Favorites grid, Privacy Report card. Matches the AppKit StartPageViewController shape
/// exactly so the visual surface is preserved across the rewrite.
struct StartPageView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MakeSafariDefaultBanner()
                    .padding(.top, 16)
                FavoritesSection()
                PrivacyReportCard()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Banner

private struct MakeSafariDefaultBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white)
                Image(systemName: "safari.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Make Safari your default browser?")
                    .font(.system(size: 13, weight: .semibold))
                Text("Safari brings faster performance, increased privacy protection, and longer battery life.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)

            Button("Make Safari Default") { /* placeholder */ }
                .controlSize(.regular)

            Button { /* dismiss */ } label: { Image(systemName: "xmark") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Favorites

private struct FavoritesSection: View {
    private let columns = Array(repeating: GridItem(.flexible(minimum: 70), spacing: 12), count: 8)
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.system(size: 16, weight: .semibold))
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(FavoritesCatalog.all) { fav in
                    FavoriteTile(favorite: fav)
                }
            }
        }
    }
}

private struct FavoriteTile: View {
    @Environment(BrowserViewModel.self) private var browser
    let favorite: Favorite
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(favorite.tint)
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                Image(systemName: favorite.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: 56, height: 56)
            Text(favorite.title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        // Drive the bottom-leading status bar overlay off favorite-tile hover, the same
        // way a real Safari window shows the link target when you hover a hyperlink.
        .onHover { hovering in
            browser.hoveredLink = hovering ? favorite.url : nil
        }
    }
}

// MARK: - Privacy Report

private struct PrivacyReportCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Privacy Report")
                .font(.system(size: 16, weight: .semibold))
            HStack(alignment: .top, spacing: 12) {
                shieldBlurb
                Spacer(minLength: 20)
                statsRow
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial,
                         in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var shieldBlurb: some View {
        HStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Safari prevents trackers from profiling you.")
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            StatCell(title: "Trackers prevented\nfrom profiling you", value: "1")
            StatCell(title: "Websites that\ncontacted trackers", value: "50 %")
            StatCell(title: "Most contacted tracker", value: "googletagmanager.com")
        }
    }
}

private struct StatCell: View {
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial,
                     in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
