cmake_minimum_required(VERSION 3.22.1)
project(webkitium_color_jni)

# Path to the portable color library. Rooted three levels up from this
# CMakeLists (app/src/main/cpp -> app/src/main -> app/src -> app -> android
# -> chrome -> webkitium root -> browser/color).
set(WEBKITIUM_COLOR_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../browser/color")

# The Android shell links a single .so: libwebkitium_color_jni.so.
# It statically bundles the color math + JNI wrapper.
add_library(webkitium_color_jni SHARED
    webkitium_color_jni.cc
    "${WEBKITIUM_COLOR_DIR}/ColorBridgeC.cc"
    "${WEBKITIUM_COLOR_DIR}/ColorRamp.cpp"
    "${WEBKITIUM_COLOR_DIR}/OklchColor.cpp"
    "${WEBKITIUM_COLOR_DIR}/SemanticPalette.cpp"
)

# browser/color/*.cpp references headers via "color/..." paths rooted at
# browser/. Add that root to the include search path.
target_include_directories(webkitium_color_jni PRIVATE
    "${WEBKITIUM_COLOR_DIR}/.."
    "${WEBKITIUM_COLOR_DIR}"
)

target_compile_features(webkitium_color_jni PRIVATE cxx_std_17)

# Android-specific link libraries.
find_library(log-lib log)
target_link_libraries(webkitium_color_jni ${log-lib})
