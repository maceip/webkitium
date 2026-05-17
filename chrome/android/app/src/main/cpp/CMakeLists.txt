cmake_minimum_required(VERSION 3.22.1)

project(webkitium_jni LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# Path to the portable browser core sources (sibling of chrome/).
set(BROWSER_DIR "${CMAKE_SOURCE_DIR}/../../../../../../browser")

# URL normalization + tracking-param scrubbing + search-engine URL builder.
# Self-contained — depends only on the C++ stdlib. No SQLite, no protobuf.
# Suggestions/history is deferred until SQLite link is wired (TODO: features.yaml#url_autocomplete).
set(URL_SOURCES
    "${BROWSER_DIR}/url/UrlNormalize.cpp"
    "${BROWSER_DIR}/url/UrlBridgeC.cc"
)

add_library(webkitium_jni SHARED
    jni_bridge.cc
    ${URL_SOURCES}
)

target_include_directories(webkitium_jni PRIVATE
    "${BROWSER_DIR}/url"
    "${BROWSER_DIR}/url/include"
)

find_library(log-lib log)
target_link_libraries(webkitium_jni PRIVATE ${log-lib})
