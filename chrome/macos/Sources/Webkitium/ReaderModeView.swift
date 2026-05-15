import SwiftUI

/// Reader Mode — overlays the page content with a clean, single-column reading layout.
/// Header has font size controls (small/large A), font picker, and theme selector
/// (white / sepia / dark / black) matching Safari's reader-mode chrome.
struct ReaderModeView: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        VStack(spacing: 0) {
            controlBar
            Divider()
            ScrollView {
                article
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity)
            }
        }
        .background(background.ignoresSafeArea())
        .foregroundStyle(textColor)
        .transition(.opacity)
    }

    // MARK: - Top control bar

    private var controlBar: some View {
        @Bindable var browserBinding = browser
        return HStack(spacing: 12) {
            Button { browser.readerFontSize = max(12, browser.readerFontSize - 1) } label: {
                Text("A").font(.system(size: 12))
            }
            .buttonStyle(.borderless)

            Button { browser.readerFontSize = min(28, browser.readerFontSize + 1) } label: {
                Text("A").font(.system(size: 17, weight: .medium))
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 16)

            ForEach(themeOptions, id: \.0) { theme, color, ring in
                Button { browser.readerTheme = theme } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(ring,
                                            lineWidth: browser.readerTheme == theme ? 2 : 1))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                withAnimation(.smooth(duration: 0.22)) { browser.readerModeOn = false }
            } label: {
                Image(systemName: "text.justify.leading")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help("Exit Reader View")
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(.regularMaterial)
    }

    private var themeOptions: [(BrowserViewModel.ReaderTheme, Color, Color)] {
        [
            (.white, .white,                                   Color.black.opacity(0.18)),
            (.sepia, Color(.sRGB, red: 0.96, green: 0.91, blue: 0.81, opacity: 1),
                                                               Color.black.opacity(0.18)),
            (.dark,  Color(.sRGB, red: 0.18, green: 0.18, blue: 0.20, opacity: 1),
                                                               Color.white.opacity(0.4)),
            (.black, .black,                                   Color.white.opacity(0.5)),
        ]
    }

    // MARK: - Article body (mock content for the visual test)

    private var article: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(browser.selectedTab?.title ?? "Apple")
                .font(.system(size: browser.readerFontSize + 14, weight: .bold))
            Text("apple.com · Reader View")
                .font(.system(size: browser.readerFontSize - 4))
                .foregroundStyle(.secondary)
            Text("This is the reader-mode rendering of the current page. Reader View strips away advertising, navigation, and other clutter so you can focus on the content. Adjust the typeface and theme to your preference using the controls at the top of the window.")
                .font(.system(size: browser.readerFontSize))
            Text("Pick a theme")
                .font(.system(size: browser.readerFontSize + 6, weight: .semibold))
                .padding(.top, 6)
            Text("Reader View supports four themes: bright white, warm sepia, dim dark gray, and pure black for OLED-friendly reading. Combine themes with the font size controls to find a comfortable layout for long-form reading.")
                .font(.system(size: browser.readerFontSize))
            Text("Reader is automatically available on most article-style pages. When the leading icon in the address bar lights up, click it to enter Reader View.")
                .font(.system(size: browser.readerFontSize))
        }
    }

    // MARK: - Theme colors

    private var background: Color {
        switch browser.readerTheme {
        case .white: return .white
        case .sepia: return Color(.sRGB, red: 0.96, green: 0.91, blue: 0.81, opacity: 1)
        case .dark:  return Color(.sRGB, red: 0.18, green: 0.18, blue: 0.20, opacity: 1)
        case .black: return .black
        }
    }
    private var textColor: Color {
        switch browser.readerTheme {
        case .white, .sepia: return .black
        case .dark, .black:  return .white
        }
    }
}
