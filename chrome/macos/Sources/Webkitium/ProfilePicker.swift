import SwiftUI

/// Profile chip + dropdown — lives at the bottom of the sidebar, showing the current
/// profile's color + name. Click opens a list of all profiles plus a "New Profile…" item.
struct ProfileFooter: View {
    @Environment(BrowserViewModel.self) private var browser

    var body: some View {
        @Bindable var browserBinding = browser
        Button {
            browser.showProfilePicker.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: browser.currentProfile.symbol)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(browser.currentProfile.color, in: Circle())
                Text(browser.currentProfile.name)
                    .font(.system(size: 12, weight: .medium))
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .popover(isPresented: $browserBinding.showProfilePicker, arrowEdge: .top) {
            ProfilePickerPopover()
                .frame(width: 200)
        }
    }
}

private struct ProfilePickerPopover: View {
    @Environment(BrowserViewModel.self) private var browser
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(browser.profiles) { p in
                Button {
                    browser.currentProfileID = p.id
                    browser.showProfilePicker = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: p.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(p.color, in: Circle())
                        Text(p.name).font(.system(size: 12))
                        Spacer(minLength: 0)
                        if p.id == browser.currentProfileID {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            Divider().padding(.vertical, 2)
            Button {
                let next = BrowserProfile(name: "New Profile",
                                            tintHex: 0x808080, symbol: "person.fill")
                browser.profiles.append(next)
                browser.currentProfileID = next.id
                browser.showProfilePicker = false
            } label: {
                Label("New Profile…", systemImage: "plus")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            Divider().padding(.vertical, 2)
            // Inline entry points to the sync and passkey windows — these are the natural
            // place for them since both surfaces are tied to the active profile/account.
            Button {
                browser.showProfilePicker = false
                openWindow(id: "sync")
            } label: {
                Label("Set Up Sync…", systemImage: "iphone.gen3")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            Button {
                browser.showProfilePicker = false
                openWindow(id: "passkeys")
            } label: {
                Label("Manage Passkeys…", systemImage: "key.horizontal.fill")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
        }
        .padding(6)
    }
}
