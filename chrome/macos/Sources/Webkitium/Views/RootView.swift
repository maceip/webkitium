// Top-level window content -- three-slot layout shell per
// design/components/shell/SPEC.md.
//
//     NavigationSplitView
//       sidebar:  workspace search + sectioned tab list + footer
//       detail :  per-tab toolbar (nav buttons + omnibar + actions)
//                 above the WebView placeholder
//
// Mirrors the Windows shell's three-slot model: the macOS variant
// uses NSVisualEffectView via SwiftUI's .background(.sidebar) and
// .background(.regularMaterial), with Liquid Glass kicking in at
// runtime on macOS 26.

import SwiftUI

struct RootView: View {
    @EnvironmentObject private var palette: PaletteProvider
    @Environment(\.colorScheme) private var colorScheme

    @State private var selectedItemID: String? = "tab-1"
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } detail: {
            contentColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            workspaceSearch
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            tabList

            Spacer(minLength: 0)

            sidebarFooter
        }
        .background(.thinMaterial)            // sidebar material
    }

    private var workspaceSearch: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            Text("Search tabs, spaces, history")
                .font(.system(size: 12))
                .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.semantic(.surfaceSunken, colorScheme: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    palette.semantic(.borderSubtle, colorScheme: colorScheme),
                    lineWidth: 1
                )
        )
    }

    private var tabList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                sectionHeader("WORKSPACE")
                sidebarRow(
                    id: "tab-1",
                    icon: "rectangle.on.rectangle",
                    label: "New Tab"
                )

                sectionHeader("SPACES")
                    .padding(.top, 12)
                sidebarRow(id: "space-personal", icon: "circle.grid.2x2", label: "Personal")
                sidebarRow(id: "space-work", icon: "circle.grid.2x2", label: "Work")
            }
            .padding(.horizontal, 8)
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(palette.semantic(.textTertiary, colorScheme: colorScheme))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    }

    private func sidebarRow(id: String, icon: String, label: String) -> some View {
        let isActive = (selectedItemID == id)
        return HStack(spacing: 8) {
            // Accent leading bar — visible only on the active row.
            Rectangle()
                .fill(isActive ? palette.semantic(.accentFill, colorScheme: colorScheme) : .clear)
                .frame(width: 3)
                .cornerRadius(2)
                .padding(.vertical, 2)

            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: 16)
                .foregroundStyle(
                    palette.semantic(isActive ? .textPrimary : .textSecondary,
                                     colorScheme: colorScheme)
                )

            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(
                    palette.semantic(isActive ? .textPrimary : .textSecondary,
                                     colorScheme: colorScheme)
                )

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive
                      ? palette.semantic(.accentFillSubtle, colorScheme: colorScheme)
                      : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { selectedItemID = id }
    }

    private var sidebarFooter: some View {
        HStack(spacing: 8) {
            Button {
                // hooks to Settings window when ready
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                    Text("Settings")
                        .font(.system(size: 13))
                        .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Account avatar chip.
            Circle()
                .fill(palette.semantic(.accentFill, colorScheme: colorScheme))
                .frame(width: 28, height: 28)
                .overlay(
                    Text("W")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            palette.semantic(.textOnBrand, colorScheme: colorScheme)
                        )
                )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(palette.semantic(.borderSubtle, colorScheme: colorScheme))
                .frame(height: 1)
        }
    }

    // MARK: - Content column

    private var contentColumn: some View {
        VStack(spacing: 0) {
            perTabToolbar

            // Hairline between toolbar and WebView.
            Rectangle()
                .fill(palette.semantic(.borderSubtle, colorScheme: colorScheme))
                .frame(height: 1)

            webContent
        }
    }

    private var perTabToolbar: some View {
        HStack(spacing: 4) {
            navButton(systemName: "chevron.backward", help: "Back")
            navButton(systemName: "chevron.forward", help: "Forward")
            navButton(systemName: "arrow.clockwise", help: "Reload (⌘R)")

            Omnibar()
                .padding(.horizontal, 8)

            navButton(systemName: "puzzlepiece.extension", help: "Extensions")
            navButton(systemName: "ellipsis", help: "More")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(height: 44)
        .background(palette.semantic(.surfaceChrome, colorScheme: colorScheme))
    }

    private func navButton(systemName: String, help: String) -> some View {
        Button { /* stub */ } label: {
            Image(systemName: systemName)
                .font(.system(size: 12))
                .foregroundStyle(palette.semantic(.textSecondary, colorScheme: colorScheme))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var webContent: some View {
        ZStack {
            palette.semantic(.surfaceCanvas, colorScheme: colorScheme)
                .ignoresSafeArea()
            Text("Web content goes here")
                .font(.system(size: 14))
                .foregroundStyle(
                    palette.semantic(.textTertiary, colorScheme: colorScheme)
                )
        }
    }
}
