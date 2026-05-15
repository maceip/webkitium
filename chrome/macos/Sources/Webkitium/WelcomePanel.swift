import SwiftUI

/// Welcome / About Safari panel — shown on first launch or via Help → Welcome. Hero
/// header + grid of feature cards calling out the headline capabilities. Matches the
/// pattern Apple uses for "What's New" panes in system apps.
struct WelcomePanel: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Image(systemName: "safari.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor.gradient)
                Text("Welcome to Safari")
                    .font(.system(size: 24, weight: .bold))
                Text("The fastest, most private way to browse on the Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                       spacing: 14) {
                FeatureCard(symbol: "person.crop.square.stack",
                             title: "Profiles",
                             detail: "Keep work, school, and personal browsing in separate spaces.")
                FeatureCard(symbol: "eyeglasses",
                             title: "Private Browsing",
                             detail: "Locked windows that don't appear in History or sync.")
                FeatureCard(symbol: "puzzlepiece.extension",
                             title: "Extensions",
                             detail: "Discover and install powerful add-ons from the integrated store.")
                FeatureCard(symbol: "key.horizontal.fill",
                             title: "Passkeys",
                             detail: "Sign in to sites with Touch ID — no password to remember.")
            }

            HStack {
                Spacer()
                Button("Get Started") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 540)
    }
}

private struct FeatureCard: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
