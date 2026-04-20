cmake_minimum_required(VERSION 3.16)
project(ng_browser_core LANGUAGES CXX)

find_package(Protobuf REQUIRED)

set(CHROMIUM_SYNC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/chromium_sync_loopback")

file(GLOB NG_CHROMIUM_SYNC_PROTOS
    "${CHROMIUM_SYNC_ROOT}/components/sync/protocol/*.proto"
)

set(NG_SYNC_PROTO_GENERATED_SOURCES)
set(NG_SYNC_PROTO_GENERATED_HEADERS)
foreach(proto_file IN LISTS NG_CHROMIUM_SYNC_PROTOS)
    file(RELATIVE_PATH proto_relative "${CHROMIUM_SYNC_ROOT}" "${proto_file}")
    set(generated_source "${CMAKE_CURRENT_BINARY_DIR}/generated/${proto_relative}")
    string(REPLACE ".proto" ".pb.cc" generated_source "${generated_source}")
    set(generated_header "${CMAKE_CURRENT_BINARY_DIR}/generated/${proto_relative}")
    string(REPLACE ".proto" ".pb.h" generated_header "${generated_header}")

    add_custom_command(
        OUTPUT "${generated_source}" "${generated_header}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/generated"
        COMMAND protobuf::protoc
            -I
            "${CHROMIUM_SYNC_ROOT}"
            --cpp_out
            "${CMAKE_CURRENT_BINARY_DIR}/generated"
            "${proto_file}"
        DEPENDS "${proto_file}"
        VERBATIM
    )

    list(APPEND NG_SYNC_PROTO_GENERATED_SOURCES "${generated_source}")
    list(APPEND NG_SYNC_PROTO_GENERATED_HEADERS "${generated_header}")
endforeach()

add_library(ng_chromium_sync_proto STATIC
    ${NG_SYNC_PROTO_GENERATED_SOURCES}
    ${NG_SYNC_PROTO_GENERATED_HEADERS}
)

target_link_libraries(ng_chromium_sync_proto PUBLIC protobuf::libprotobuf)
target_include_directories(ng_chromium_sync_proto SYSTEM PUBLIC
    "${CMAKE_CURRENT_BINARY_DIR}/generated"
)

if (MSVC)
    target_compile_options(ng_chromium_sync_proto PRIVATE /wd4996)
else()
    target_compile_options(ng_chromium_sync_proto PRIVATE -Wno-deprecated-declarations)
endif()

set(NG_BROWSER_CORE_SOURCES
    core/Origin.cpp
    forms/FormFiller.cpp
    extensions/ExtensionManifest.cpp
    extensions/ExtensionRegistry.cpp
    extensions/ExtensionRuntime.cpp
    sync/ChromiumSyncWireAdapter.cpp
    sync/LoopbackSyncClient.cpp
    sync/LoopbackSyncRpc.cpp
    sync/LoopbackSyncServer.cpp
    sync/SyncTypes.cpp
    tabs/BrowserCommandController.cpp
    tabs/BrowserStateModel.cpp
    webauthn/WebAuthnController.cpp
)

if(WIN32)
    list(APPEND NG_BROWSER_CORE_SOURCES platform/windows/WindowsWebAuthnProvider.cpp)
endif()

if(ANDROID)
    list(APPEND NG_BROWSER_CORE_SOURCES
        platform/android/AndroidWebAuthnProvider.cpp
        platform/android/WebAuthnCredentialManagerJson.cpp
    )
endif()

set(NG_MACOS_WEBAUTHN OFF)
if(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    string(TOLOWER "${CMAKE_OSX_SYSROOT}" _ng_osx_sysroot)
    if(NOT _ng_osx_sysroot MATCHES "iphoneos|iphonesimulator")
        set(NG_MACOS_WEBAUTHN ON)
    endif()
endif()

if(NG_MACOS_WEBAUTHN)
    enable_language(OBJCXX)
    list(APPEND NG_BROWSER_CORE_SOURCES platform/macos/MacOSWebAuthnProvider.mm)
endif()

add_library(ng_browser_core STATIC ${NG_BROWSER_CORE_SOURCES})

target_compile_features(ng_browser_core PUBLIC cxx_std_17)
target_include_directories(ng_browser_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(ng_browser_core PUBLIC ng_chromium_sync_proto)

if(NG_MACOS_WEBAUTHN)
    target_link_libraries(ng_browser_core PRIVATE
        "-framework AuthenticationServices"
        "-framework Foundation"
        "-framework AppKit"
    )
    set_source_files_properties(platform/macos/MacOSWebAuthnProvider.mm PROPERTIES
        COMPILE_FLAGS "-fobjc-arc"
    )
endif()

if(WIN32)
    target_link_libraries(ng_browser_core PRIVATE webauthn)

    add_executable(ng_windows_webauthn_capabilities_test
        tests/WindowsWebAuthnCapabilitiesTest.cpp
    )
    target_link_libraries(ng_windows_webauthn_capabilities_test PRIVATE ng_browser_core)
    add_test(NAME ng_windows_webauthn_capabilities_test COMMAND ng_windows_webauthn_capabilities_test)
endif()

if (MSVC)
    target_compile_options(ng_browser_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(ng_browser_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

enable_testing()

add_executable(ng_browser_core_smoke
    tests/BrowserCoreSmoke.cpp
)

target_link_libraries(ng_browser_core_smoke PRIVATE ng_browser_core)
add_test(NAME ng_browser_core_smoke COMMAND ng_browser_core_smoke)

add_executable(ng_cross_platform_host
    app/CrossPlatformHost.cpp
)

target_link_libraries(ng_cross_platform_host PRIVATE ng_browser_core)
add_test(NAME ng_cross_platform_host COMMAND ng_cross_platform_host)

add_executable(ng_form_filler_test
    tests/FormFillerTest.cpp
)

target_link_libraries(ng_form_filler_test PRIVATE ng_browser_core)
add_test(NAME ng_form_filler_test COMMAND ng_form_filler_test)

add_executable(ng_loopback_sync_test
    tests/LoopbackSyncTest.cpp
)

target_link_libraries(ng_loopback_sync_test PRIVATE ng_browser_core)
add_test(NAME ng_loopback_sync_test COMMAND ng_loopback_sync_test)

add_executable(ng_chromium_sync_wire_test
    tests/ChromiumSyncWireAdapterTest.cpp
)

target_link_libraries(ng_chromium_sync_wire_test PRIVATE ng_browser_core)
add_test(NAME ng_chromium_sync_wire_test COMMAND ng_chromium_sync_wire_test)

set(NG_ANDROID_WEBAUTHN_JSON_TEST_SOURCES
    tests/AndroidWebAuthnJsonTest.cpp
)

if(NOT ANDROID)
    list(APPEND NG_ANDROID_WEBAUTHN_JSON_TEST_SOURCES platform/android/WebAuthnCredentialManagerJson.cpp)
endif()

add_executable(ng_android_webauthn_json_test ${NG_ANDROID_WEBAUTHN_JSON_TEST_SOURCES})

target_link_libraries(ng_android_webauthn_json_test PRIVATE ng_browser_core)
add_test(NAME ng_android_webauthn_json_test COMMAND ng_android_webauthn_json_test)
