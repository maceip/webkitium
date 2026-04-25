// JNI shim for browser/webauthn/WebAuthnBridgeC.h.

#include <jni.h>

#include "webauthn/WebAuthnBridgeC.h"

extern "C" {

JNIEXPORT jlong JNICALL
Java_dev_webkitium_services_WebAuthnBridge_nativeCreate(JNIEnv*, jclass) {
    return reinterpret_cast<jlong>(wk_webauthn_create());
}

JNIEXPORT void JNICALL
Java_dev_webkitium_services_WebAuthnBridge_nativeDestroy(JNIEnv*, jclass, jlong handle) {
    wk_webauthn_destroy(reinterpret_cast<WkWebAuthn*>(handle));
}

JNIEXPORT jboolean JNICALL
Java_dev_webkitium_services_WebAuthnBridge_nativeIsInitialized(JNIEnv*, jclass, jlong handle) {
    return wk_webauthn_is_initialized(reinterpret_cast<WkWebAuthn*>(handle)) ? JNI_TRUE : JNI_FALSE;
}

JNIEXPORT jint JNICALL
Java_dev_webkitium_services_WebAuthnBridge_nativeRequestCount(JNIEnv*, jclass, jlong handle) {
    return wk_webauthn_request_count(reinterpret_cast<WkWebAuthn*>(handle));
}

JNIEXPORT jint JNICALL
Java_dev_webkitium_services_WebAuthnBridge_nativeRejectionCount(JNIEnv*, jclass, jlong handle) {
    return wk_webauthn_rejection_count(reinterpret_cast<WkWebAuthn*>(handle));
}

}
