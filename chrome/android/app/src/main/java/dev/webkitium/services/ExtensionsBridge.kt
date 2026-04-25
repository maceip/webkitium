package dev.webkitium.services

/**
 * Kotlin face of [browser/extensions/ExtensionBridgeC.h].
 *
 * The shared library is libwebkitium_color_jni.so (named for the
 * original color bridge; now a single .so bundling every C ABI bridge
 * + JNI shim).  ColorBridge.kt loads it; we depend on that init.
 */
object ExtensionsBridge {
    @JvmStatic private external fun nativeCreate(): Long
    @JvmStatic private external fun nativeDestroy(handle: Long)
    @JvmStatic private external fun nativeCount(handle: Long): Int
    @JvmStatic private external fun nativeIdAt(handle: Long, index: Int): String?
    @JvmStatic private external fun nativeNameAt(handle: Long, index: Int): String?

    fun create(): Long = nativeCreate()
    fun destroy(handle: Long) = nativeDestroy(handle)
    fun count(handle: Long): Int = nativeCount(handle)
    fun idAt(handle: Long, index: Int): String? = nativeIdAt(handle, index)
    fun nameAt(handle: Long, index: Int): String? = nativeNameAt(handle, index)
}
