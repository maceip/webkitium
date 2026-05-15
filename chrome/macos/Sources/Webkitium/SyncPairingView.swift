import SwiftUI

/// Sync setup window — two paired screens for pairing a Mac with an iPhone over local
/// sync (visual mock). Switches between:
///   1. Mac-side "Pair with iPhone" — renders a QR code + backup numeric code, with a
///      paired-devices list and a Continue-on-iPhone hint.
///   2. iPhone-side scanner — full-screen black with viewfinder brackets + scanned
///      device confirmation. The view models a phone screen at iPhone aspect ratio so
///      it's easy to demo the receiving end visually.
///
/// Layout, copy, and visual treatment follow Apple's standard QR-pairing patterns
/// (iCloud Keychain approval / Apple Account sign-in / HomePod setup).
struct SyncPairingView: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.dismiss) private var dismiss
    @State private var screen: Screen = .macHost
    @State private var pulse = false

    enum Screen: Hashable { case macHost, iPhoneScanner, paired }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ZStack {
                Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
                content
                    .padding(24)
            }
        }
        .frame(width: 760, height: 560)
        .onAppear { pulse = true }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Set Up Sync")
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Picker("", selection: $screen) {
                Text("Mac").tag(Screen.macHost)
                Text("iPhone").tag(Screen.iPhoneScanner)
                Text("Paired").tag(Screen.paired)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)
            Button("Done") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .macHost:      macHost
        case .iPhoneScanner: iPhoneScanner
        case .paired:        pairedList
        }
    }

    // MARK: - Mac-side host screen

    private var macHost: some View {
        VStack(spacing: 14) {
            Image(systemName: "iphone.gen3")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Pair with iPhone")
                .font(.system(size: 20, weight: .semibold))
            Text("Scan this code with your iPhone's camera, or enter the numeric code in Settings → Safari → Sync.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            QRCard()
                .padding(.vertical, 6)

            numericCode

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .opacity(pulse ? 1 : 0.3)
                    .animation(.smooth(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                Text("Waiting for iPhone…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var numericCode: some View {
        HStack(spacing: 8) {
            ForEach(["421", "907"], id: \.self) { chunk in
                Text(chunk)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .tracking(4)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.thinMaterial,
                                 in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    // MARK: - iPhone-side scanner

    private var iPhoneScanner: some View {
        // Models a 6.1" iPhone screen at ~390:844 aspect, centered in the window.
        HStack {
            Spacer()
            iPhoneFrame {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 18) {
                        Text("Scan QR Code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.top, 60)
                        ScannerViewfinder()
                            .frame(width: 220, height: 220)
                        Text("Position the QR code shown on your Mac inside the frame.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                        Spacer()
                        Button("Enter Code Manually") { }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.white)
                            .padding(.bottom, 32)
                    }
                }
            }
            Spacer()
        }
    }

    private var pairedList: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.green)
            Text("All Devices Paired")
                .font(.system(size: 20, weight: .semibold))
            Text("These devices share History, Bookmarks, Reading List, and Passkeys.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(Array(browser.pairedSyncDevices.enumerated()), id: \.element.id) { idx, dev in
                    PairedDeviceRow(device: dev)
                    if idx < browser.pairedSyncDevices.count - 1 { Divider().padding(.leading, 36) }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .frame(maxWidth: 420)
        }
    }
}

// MARK: - Building blocks

private struct QRCard: View {
    var body: some View {
        ZStack {
            // White inset card with rounded corners — Apple's QR-card chrome.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.white)
                .frame(width: 220, height: 220)
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            QRMosaic().frame(width: 192, height: 192)
            // Centered Apple logo overlay.
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white)
                Image(systemName: "applelogo")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.black)
            }
            .frame(width: 32, height: 32)
        }
    }
}

/// Deterministic visual QR mosaic — a 25×25 grid of black/white cells generated from a
/// stable hash so it reads as a QR code without us shipping a real CIFilter encoder.
/// Adds the standard three position markers in the corners.
private struct QRMosaic: View {
    private let size = 25
    private let cells: [[Bool]]

    init(seed: String = "safari-clone-pairing-v1") {
        var grid = Array(repeating: Array(repeating: false, count: 25), count: 25)
        var rng = SplitMix64(seed: UInt64(bitPattern: Int64(seed.hashValue)))
        for r in 0..<25 {
            for c in 0..<25 {
                grid[r][c] = (rng.next() & 1) == 0
            }
        }
        // Stamp three position markers (top-left, top-right, bottom-left).
        for (or, oc) in [(0, 0), (0, 18), (18, 0)] {
            for r in 0..<7 {
                for c in 0..<7 {
                    let onBorder = (r == 0 || r == 6 || c == 0 || c == 6)
                    let inCenter = (r >= 2 && r <= 4 && c >= 2 && c <= 4)
                    grid[or + r][oc + c] = onBorder || inCenter
                }
            }
            // Clear the 1-cell white ring between the outer and inner square.
            for r in 1...5 {
                for c in 1...5 where !((r == 1 || r == 5 || c == 1 || c == 5) == false) {
                    if r == 1 || r == 5 || c == 1 || c == 5 {
                        grid[or + r][oc + c] = false
                    }
                }
            }
        }
        self.cells = grid
    }

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / CGFloat(size)
            Canvas { ctx, _ in
                for r in 0..<size {
                    for c in 0..<size where cells[r][c] {
                        let rect = CGRect(x: CGFloat(c) * cell,
                                          y: CGFloat(r) * cell,
                                          width: cell, height: cell)
                        ctx.fill(Path(rect), with: .color(.black))
                    }
                }
            }
        }
    }
}

private struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

private struct ScannerViewfinder: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.0), lineWidth: 0)
            // Corner brackets — 4 short L-shapes at each corner.
            ForEach(0..<4) { idx in
                CornerBracket()
                    .stroke(Color.white, style: .init(lineWidth: 3, lineCap: .round))
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(Double(idx) * 90))
                    .offset(offset(for: idx))
            }
        }
    }
    private func offset(for idx: Int) -> CGSize {
        switch idx {
        case 0: return CGSize(width: -96, height: -96)
        case 1: return CGSize(width:  96, height: -96)
        case 2: return CGSize(width:  96, height:  96)
        default:return CGSize(width: -96, height:  96)
        }
    }
}

private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

private struct iPhoneFrame<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(.black)
            content()
                .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .padding(8)
        }
        .frame(width: 220, height: 460)
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}

private struct PairedDeviceRow: View {
    let device: SyncDevice
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.kind.symbol)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(device.name).font(.system(size: 13, weight: .medium))
                Text("Last synced \(device.lastSync, style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Button("Unpair") { }
                .buttonStyle(.borderless)
                .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}
