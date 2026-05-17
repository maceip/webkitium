# Keep JNI entry points reachable from native code.
-keep class org.webkitium.android.ffi.** { *; }
-keepclassmembers class org.webkitium.android.ffi.** {
    native <methods>;
}
