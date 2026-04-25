package dev.webkitium.services

object SyncBridge {
    @JvmStatic private external fun nativeCreate(): Long
    @JvmStatic private external fun nativeDestroy(handle: Long)
    @JvmStatic private external fun nativeRecordCount(handle: Long): Int
    @JvmStatic private external fun nativeCurrentVersion(handle: Long): Long
    @JvmStatic private external fun nativeStoreBirthday(handle: Long): String?

    fun create(): Long = nativeCreate()
    fun destroy(handle: Long) = nativeDestroy(handle)
    fun recordCount(handle: Long): Int = nativeRecordCount(handle)
    fun currentVersion(handle: Long): Long = nativeCurrentVersion(handle)
    fun storeBirthday(handle: Long): String? = nativeStoreBirthday(handle)
}
