package org.webkitium.android.ffi

/**
 * JNI bridge to the portable C ABI in browser/url/UrlBridgeC.h.
 * Load-bearing proof-of-life that the C++ core links from the NDK side.
 */
object UrlBridge {

    init {
        System.loadLibrary("webkitium_jni")
    }

    /** Mirror of NormalizeKind in UrlBridgeC.h. */
    enum class NormalizeKind(val raw: Int) {
        Url(0),
        Search(1);

        companion object {
            fun fromRaw(v: Int): NormalizeKind = when (v) {
                0    -> Url
                1    -> Search
                else -> Url
            }
        }
    }

    /**
     * Returned across JNI by name — keep the constructor signature
     * matching jni_bridge.cc's GetMethodID call: (ILjava/lang/String;)V.
     */
    data class NormalizeResult(val kindRaw: Int, val url: String) {
        val kind: NormalizeKind get() = NormalizeKind.fromRaw(kindRaw)
    }

    private external fun normalizeNative(raw: String, engine: String): NormalizeResult?
    private external fun scrubTrackingNative(url: String): String?

    fun normalize(raw: String, engine: String = "duckduckgo"): NormalizeResult? =
        normalizeNative(raw, engine)

    fun scrubTracking(url: String): String? = scrubTrackingNative(url)
}
