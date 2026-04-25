package dev.webkitium.services

object WebAuthnBridge {
    @JvmStatic private external fun nativeCreate(): Long
    @JvmStatic private external fun nativeDestroy(handle: Long)
    @JvmStatic private external fun nativeIsInitialized(handle: Long): Boolean
    @JvmStatic private external fun nativeRequestCount(handle: Long): Int
    @JvmStatic private external fun nativeRejectionCount(handle: Long): Int

    fun create(): Long = nativeCreate()
    fun destroy(handle: Long) = nativeDestroy(handle)
    fun isInitialized(handle: Long): Boolean = nativeIsInitialized(handle)
    fun requestCount(handle: Long): Int = nativeRequestCount(handle)
    fun rejectionCount(handle: Long): Int = nativeRejectionCount(handle)
}
