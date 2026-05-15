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
        // The C `create` functions return `Wk*?` which Swift maps to `OpaquePointer?`.
        // No further wrapping required.
        guard let ext  = wk_extensions_create(),
              let sync = wk_sync_create(),
              let wa   = wk_webauthn_create() else {
            return nil
        }
        self.extensionsHandle = ext
        self.syncHandle       = sync
        self.webAuthnHandle   = wa
    }

    deinit {
        // The C ABI types `Wk*` map to `OpaquePointer` in Swift; pass the handles
        // directly. (Wrapping in `UnsafeMutablePointer(...)` was an upstream bug —
        // Swift can't infer Pointee for a fresh-pointer constructor and the C funcs
        // expect the opaque type directly.)
        wk_extensions_destroy(extensionsHandle)
        wk_sync_destroy(syncHandle)
        wk_webauthn_destroy(webAuthnHandle)
    }

    // MARK: - Extensions

    var extensionCount: Int {
        Int(wk_extensions_count(extensionsHandle))
    }

    // MARK: - Sync

    var syncRecordCount: Int {
        Int(wk_sync_record_count(syncHandle))
    }

    var syncCurrentVersion: Int64 {
        wk_sync_current_version(syncHandle)
    }

    // MARK: - WebAuthn

    var webAuthnReady: Bool {
        wk_webauthn_is_initialized(webAuthnHandle) != 0
    }

    var webAuthnRequestCount: Int {
        Int(wk_webauthn_request_count(webAuthnHandle))
    }

    var webAuthnRejectionCount: Int {
        Int(wk_webauthn_rejection_count(webAuthnHandle))
    }
}
