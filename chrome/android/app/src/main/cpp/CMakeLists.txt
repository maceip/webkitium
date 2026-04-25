cmake_minimum_required(VERSION 3.22.1)
project(webkitium_color_jni)

# Path to the portable browser/ tree.  app/src/main/cpp ->
# app/src/main -> app/src -> app -> android -> chrome -> webkitium root.
set(BROWSER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../browser")

# Single shared .so bundling all C ABI bridges + their JNI shims.
# Kotlin loads it via System.loadLibrary("webkitium_color_jni").
add_library(webkitium_color_jni SHARED
    # color/
    webkitium_color_jni.cc
    "${BROWSER_DIR}/color/ColorBridgeC.cc"
    "${BROWSER_DIR}/color/ColorRamp.cpp"
    "${BROWSER_DIR}/color/OklchColor.cpp"
    "${BROWSER_DIR}/color/SemanticPalette.cpp"

    # extensions/
    webkitium_extensions_jni.cc
    "${BROWSER_DIR}/extensions/ExtensionBridgeC.cc"
    "${BROWSER_DIR}/extensions/ExtensionManifest.cpp"
    "${BROWSER_DIR}/extensions/ExtensionRegistry.cpp"

    # sync/  (stub today)
    webkitium_sync_jni.cc
    "${BROWSER_DIR}/sync/SyncBridgeC.cc"

    # webauthn/
    webkitium_webauthn_jni.cc
    "${BROWSER_DIR}/core/Origin.cpp"
    "${BROWSER_DIR}/webauthn/WebAuthnBridgeC.cc"
    "${BROWSER_DIR}/webauthn/WebAuthnController.cpp"
)

target_include_directories(webkitium_color_jni PRIVATE "${BROWSER_DIR}")

target_compile_features(webkitium_color_jni PRIVATE cxx_std_17)

find_library(log-lib log)
target_link_libraries(webkitium_color_jni ${log-lib})
