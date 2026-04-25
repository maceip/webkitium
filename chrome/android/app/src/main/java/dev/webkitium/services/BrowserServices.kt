package dev.webkitium.services

import android.util.Log
import dev.webkitium.theme.ColorBridge

/**
 * Process-wide holder for the wired-but-inactive controllers.
 *
 * Touching ColorBridge first ensures libwebkitium_color_jni.so is
 * loaded (System.loadLibrary in its companion init) before any of the
 * other Bridge objects bind their external functions.
 *
 * Constructed once at app startup (see MainActivity.onCreate).
 */
class BrowserServices private constructor(
    private val extensionsHandle: Long,
    private val syncHandle: Long,
    private val webAuthnHandle: Long,
) {

    val extensionCount: Int
        get() = ExtensionsBridge.count(extensionsHandle)

    val syncRecordCount: Int
        get() = SyncBridge.recordCount(syncHandle)

    val syncCurrentVersion: Long
        get() = SyncBridge.currentVersion(syncHandle)

    val webAuthnReady: Boolean
        get() = WebAuthnBridge.isInitialized(webAuthnHandle)

    val webAuthnRequestCount: Int
        get() = WebAuthnBridge.requestCount(webAuthnHandle)

    val webAuthnRejectionCount: Int
        get() = WebAuthnBridge.rejectionCount(webAuthnHandle)

    fun dispose() {
        ExtensionsBridge.destroy(extensionsHandle)
        SyncBridge.destroy(syncHandle)
        WebAuthnBridge.destroy(webAuthnHandle)
    }

    companion object {
        private const val TAG = "WebkitiumServices"

        fun create(): BrowserServices? {
            // Force the .so to load via ColorBridge's class-init loadLibrary.
            // Class reference triggers init; reading SEMANTIC_TOKEN_COUNT keeps it alive.
            try {
                val ignore = ColorBridge.SEMANTIC_TOKEN_COUNT
                require(ignore > 0)
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to load native library", t)
                return null
            }
            val ext = ExtensionsBridge.create()
            val sync = SyncBridge.create()
            val wa = WebAuthnBridge.create()
            if (ext == 0L || sync == 0L || wa == 0L) {
                if (ext != 0L) ExtensionsBridge.destroy(ext)
                if (sync != 0L) SyncBridge.destroy(sync)
                if (wa != 0L) WebAuthnBridge.destroy(wa)
                return null
            }
            return BrowserServices(ext, sync, wa)
        }
    }
}
