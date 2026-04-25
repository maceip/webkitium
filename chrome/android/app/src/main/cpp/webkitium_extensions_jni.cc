// JNI shim for browser/extensions/ExtensionBridgeC.h.
//
// Kotlin side: dev.webkitium.services.ExtensionsBridge declares the
// matching `external fun` set; this shim marshals through the C ABI.
// The shared library libwebkitium_jni.so is loaded once on class init.

#include <jni.h>

#include "extensions/ExtensionBridgeC.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_dev_webkitium_services_ExtensionsBridge_nativeCreate(JNIEnv*, jclass) {
    return reinterpret_cast<jlong>(wk_extensions_create());
}

JNIEXPORT void JNICALL
Java_dev_webkitium_services_ExtensionsBridge_nativeDestroy(JNIEnv*, jclass, jlong handle) {
    wk_extensions_destroy(reinterpret_cast<WkExtensionRegistry*>(handle));
}

JNIEXPORT jint JNICALL
Java_dev_webkitium_services_ExtensionsBridge_nativeCount(JNIEnv*, jclass, jlong handle) {
    return wk_extensions_count(reinterpret_cast<WkExtensionRegistry*>(handle));
}

JNIEXPORT jstring JNICALL
Java_dev_webkitium_services_ExtensionsBridge_nativeIdAt(JNIEnv* env, jclass, jlong handle, jint index) {
    char* s = wk_extensions_id_at(reinterpret_cast<WkExtensionRegistry*>(handle), index);
    if (!s) return nullptr;
    jstring js = env->NewStringUTF(s);
    wk_extensions_string_free(s);
    return js;
}

JNIEXPORT jstring JNICALL
Java_dev_webkitium_services_ExtensionsBridge_nativeNameAt(JNIEnv* env, jclass, jlong handle, jint index) {
    char* s = wk_extensions_name_at(reinterpret_cast<WkExtensionRegistry*>(handle), index);
    if (!s) return nullptr;
    jstring js = env->NewStringUTF(s);
    wk_extensions_string_free(s);
    return js;
}

}
