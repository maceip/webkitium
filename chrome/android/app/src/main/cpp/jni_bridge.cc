// JNI glue between Kotlin (org.webkitium.android.ffi.UrlBridge) and the
// portable C ABI at browser/url/UrlBridgeC.h.
//
// Memory contract: wk_url_normalize writes a malloc'd string into out_url
// on success (return >= 0); the caller must release it via wk_url_free.
// Both branches are handled before returning to Kotlin.

#include <jni.h>
#include <android/log.h>
#include <cstdlib>
#include <cstring>

#include "UrlBridgeC.h"

#define LOG_TAG "WebkitiumJNI"
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

namespace {

jobject make_normalize_result(JNIEnv* env, jint kind, const char* url) {
    jclass cls = env->FindClass("org/webkitium/android/ffi/UrlBridge$NormalizeResult");
    if (cls == nullptr) {
        LOGE("NormalizeResult class not found");
        return nullptr;
    }
    jmethodID ctor = env->GetMethodID(cls, "<init>", "(ILjava/lang/String;)V");
    if (ctor == nullptr) {
        LOGE("NormalizeResult ctor not found");
        env->DeleteLocalRef(cls);
        return nullptr;
    }
    jstring jurl = env->NewStringUTF(url == nullptr ? "" : url);
    jobject result = env->NewObject(cls, ctor, kind, jurl);
    env->DeleteLocalRef(jurl);
    env->DeleteLocalRef(cls);
    return result;
}

}  // namespace

extern "C" JNIEXPORT jobject JNICALL
Java_org_webkitium_android_ffi_UrlBridge_normalizeNative(
        JNIEnv* env, jobject /* this */, jstring raw, jstring engine) {
    if (raw == nullptr) return nullptr;

    const char* c_raw = env->GetStringUTFChars(raw, nullptr);
    if (env->ExceptionCheck() || c_raw == nullptr) {
        // OOM during string materialisation — the JVM has the exception
        // pending; surface null back to Kotlin and let it propagate.
        return nullptr;
    }

    const char* c_engine = nullptr;
    if (engine != nullptr) {
        c_engine = env->GetStringUTFChars(engine, nullptr);
        if (env->ExceptionCheck() || c_engine == nullptr) {
            env->ReleaseStringUTFChars(raw, c_raw);
            return nullptr;
        }
    }

    char* out_url = nullptr;
    int kind = wk_url_normalize(c_raw, c_engine, &out_url);

    env->ReleaseStringUTFChars(raw, c_raw);
    if (c_engine != nullptr) env->ReleaseStringUTFChars(engine, c_engine);

    if (kind < 0) {
        if (out_url) wk_url_free(out_url);
        return nullptr;
    }

    jobject result = make_normalize_result(env, kind, out_url);
    if (out_url) wk_url_free(out_url);
    return result;
}

extern "C" JNIEXPORT jstring JNICALL
Java_org_webkitium_android_ffi_UrlBridge_scrubTrackingNative(
        JNIEnv* env, jobject /* this */, jstring url) {
    if (url == nullptr) return nullptr;
    const char* c_url = env->GetStringUTFChars(url, nullptr);
    if (env->ExceptionCheck() || c_url == nullptr) return nullptr;

    char* scrubbed = wk_url_scrub_tracking(c_url);
    env->ReleaseStringUTFChars(url, c_url);
    if (!scrubbed) return nullptr;

    jstring result = env->NewStringUTF(scrubbed);
    wk_url_free(scrubbed);
    return result;
}
