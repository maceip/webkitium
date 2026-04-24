// Top-level window content — omnibar band + content surface.
//
// Analog of chrome/windows/src/MainWindow.xaml: the layout is a
// two-row column, row 0 is the title-bar band containing the omnibar
// pill, row 1 is the content surface (placeholder until the WebKit
// Windows/macOS port lands).

import SwiftUI

struct RootView: View {
    // Width reserved for the macOS traffic-light cluster at the leading
    // edge of the title bar. Matches Apple's HIG default (70pt) with a
    // small gap.
    private let trafficLightReserveWidth: CGFloat = 80
    // Matching reserve on the trailing edge so the pill remains centered
    // even when the window's Mica-equivalent sheen is asymmetric.
    private let trailingReserveWidth: CGFloat = 80

    @EnvironmentObject private var palette: PaletteProvider
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            titleBarBand
                .frame(height: 44)

            contentSurface
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
        }
        .background(
            // Liquid Glass on macOS 26, .ultraThinMaterial fallback.
            // We wrap in a ZStack so the material sits below our content
            // while still showing whatever wallpaper/desktop is behind.
            Rectangle().fill(.ultraThinMaterial)
        )
    }

    // MARK: - Title bar / omnibar band

    private var titleBarBand: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: trafficLightReserveWidth)
            Omnibar()
                .frame(maxWidth: 720)
                .padding(.horizontal, 8)
            Spacer().frame(width: trailingReserveWidth)
        }
    }

    // MARK: - Content

    private var contentSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(palette.semantic(.surfaceCanvas, colorScheme: colorScheme))

            Text("Web content goes here")
                .font(.system(size: 14))
                .foregroundStyle(
                    palette.semantic(.textTertiary, colorScheme: colorScheme)
                )
        }
    }
}
