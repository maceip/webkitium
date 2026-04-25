// JNI shim for browser/sync/SyncBridgeC.h.

#include <jni.h>

#include "sync/SyncBridgeC.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_dev_webkitium_services_SyncBridge_nativeCreate(JNIEnv*, jclass) {
    return reinterpret_cast<jlong>(wk_sync_create());
}

JNIEXPORT void JNICALL
Java_dev_webkitium_services_SyncBridge_nativeDestroy(JNIEnv*, jclass, jlong handle) {
    wk_sync_destroy(reinterpret_cast<WkSyncStatus*>(handle));
}

JNIEXPORT jint JNICALL
Java_dev_webkitium_services_SyncBridge_nativeRecordCount(JNIEnv*, jclass, jlong handle) {
    return wk_sync_record_count(reinterpret_cast<WkSyncStatus*>(handle));
}

JNIEXPORT jlong JNICALL
Java_dev_webkitium_services_SyncBridge_nativeCurrentVersion(JNIEnv*, jclass, jlong handle) {
    return static_cast<jlong>(wk_sync_current_version(reinterpret_cast<WkSyncStatus*>(handle)));
}

JNIEXPORT jstring JNICALL
Java_dev_webkitium_services_SyncBridge_nativeStoreBirthday(JNIEnv* env, jclass, jlong handle) {
    char* s = wk_sync_store_birthday(reinterpret_cast<WkSyncStatus*>(handle));
    if (!s) return nullptr;
    jstring js = env->NewStringUTF(s);
    wk_sync_string_free(s);
    return js;
}

}
