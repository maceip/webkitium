// Process-wide holder for the wired-but-inactive controllers.
//
// Three opaque handles to the C ABI bridges in browser/:
//   - extensions: ExtensionRegistry (real, empty until install())
//   - sync: stub status surface; expands to LoopbackSyncServer when activated
//   - webauthn: WebAuthnController over an inactive provider
//
// Constructed once in WebkitiumApp; owned for the app lifetime.  No UI
// surfaces invoke these yet -- the SwiftUI side reads counts.

import Foundation
import WebkitiumExtensions
import WebkitiumSync
import WebkitiumWebAuthn

@MainActor
final class BrowserServices {
    private let extensionsHandle: OpaquePointer
    private let syncHandle:       OpaquePointer
    private let webAuthnHandle:   OpaquePointer

    init?() {
        guard let ext = wk_extensions_create(),
              let sync = wk_sync_create(),
              let wa  = wk_webauthn_create() else {
            return nil
        }
        self.extensionsHandle = OpaquePointer(ext)
        self.syncHandle       = OpaquePointer(sync)
        self.webAuthnHandle   = OpaquePointer(wa)
    }

    deinit {
        wk_extensions_destroy(UnsafeMutablePointer(extensionsHandle))
        wk_sync_destroy(UnsafeMutablePointer(syncHandle))
        wk_webauthn_destroy(UnsafeMutablePointer(webAuthnHandle))
    }

    // MARK: - Extensions

    var extensionCount: Int {
        Int(wk_extensions_count(UnsafePointer(extensionsHandle)))
    }

    // MARK: - Sync

    var syncRecordCount: Int {
        Int(wk_sync_record_count(UnsafePointer(syncHandle)))
    }

    var syncCurrentVersion: Int64 {
        wk_sync_current_version(UnsafePointer(syncHandle))
    }

    // MARK: - WebAuthn

    var webAuthnReady: Bool {
        wk_webauthn_is_initialized(UnsafePointer(webAuthnHandle)) != 0
    }

    var webAuthnRequestCount: Int {
        Int(wk_webauthn_request_count(UnsafePointer(webAuthnHandle)))
    }

    var webAuthnRejectionCount: Int {
        Int(wk_webauthn_rejection_count(UnsafePointer(webAuthnHandle)))
    }
}
