cmake_minimum_required(VERSION 3.21)
project(webkitium_min LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

# ── WebKit source + build locations ────────────────────────────────────────
# Override on the cmake command line: -DWEBKIT_SRC=... -DWEBKIT_BUILD=...
set(WEBKIT_SRC "C:/W/webkit-src" CACHE PATH "Path to WebKit source tree")
set(WEBKIT_BUILD "${WEBKIT_SRC}/WebKitBuild/Debug" CACHE PATH "Path to WebKit build output (Debug)")

if(NOT EXISTS "${WEBKIT_SRC}")
    message(WARNING "WEBKIT_SRC does not exist: ${WEBKIT_SRC}")
endif()
if(NOT EXISTS "${WEBKIT_BUILD}/bin")
    message(WARNING "WEBKIT_BUILD/bin does not exist: ${WEBKIT_BUILD}/bin -- did build-webkit run?")
endif()

# Headers ─ Apple Win port C API.
# WebKit's C API headers live in two places we need on the include path:
#   Source/WebKit/UIProcess/API/C            (cross-platform C API)
#   Source/WebKit/UIProcess/API/C/win        (Win-specific: WKView.h)
# Source files include them as <WebKit/WKContext.h> etc — the build also
# installs forwarding headers under WebKitBuild/<config>/{Include,DerivedSources}.
# We point at both raw API dirs plus the build's forwarding headers for safety.
set(WEBKIT_INCLUDE_DIRS
    "${WEBKIT_SRC}/Source/WebKit/UIProcess/API/C"
    "${WEBKIT_SRC}/Source/WebKit/UIProcess/API/C/win"
    "${WEBKIT_BUILD}/Include"
    "${WEBKIT_BUILD}/Include/WebKit"
    "${WEBKIT_BUILD}/DerivedSources/ForwardingHeaders"
)

# Import libs produced alongside the DLLs.
set(WEBKIT_LINK_LIBS
    "${WEBKIT_BUILD}/lib/WebKit.lib"
    "${WEBKIT_BUILD}/lib/JavaScriptCore.lib"
    "${WEBKIT_BUILD}/lib/WTF.lib"
)
# build-webkit sometimes puts import libs next to the DLLs in /bin. Fall back.
foreach(lib WebKit JavaScriptCore WTF)
    if(NOT EXISTS "${WEBKIT_BUILD}/lib/${lib}.lib" AND EXISTS "${WEBKIT_BUILD}/bin/${lib}.lib")
        list(REMOVE_ITEM WEBKIT_LINK_LIBS "${WEBKIT_BUILD}/lib/${lib}.lib")
        list(APPEND WEBKIT_LINK_LIBS "${WEBKIT_BUILD}/bin/${lib}.lib")
    endif()
endforeach()

add_executable(webkitium_min WIN32 main.cpp)

target_include_directories(webkitium_min PRIVATE ${WEBKIT_INCLUDE_DIRS})

target_link_libraries(webkitium_min PRIVATE
    ${WEBKIT_LINK_LIBS}
    user32 gdi32 ole32 windowscodecs shell32
)

target_compile_definitions(webkitium_min PRIVATE
    UNICODE _UNICODE
    NOMINMAX WIN32_LEAN_AND_MEAN
)

if(MSVC)
    target_compile_options(webkitium_min PRIVATE /W3 /permissive- /Zc:__cplusplus)
endif()

# Post-build: stage the WebKit runtime DLLs next to the EXE so it launches.
file(GLOB WEBKIT_RUNTIME_DLLS "${WEBKIT_BUILD}/bin/*.dll")
if(WEBKIT_RUNTIME_DLLS)
    add_custom_command(TARGET webkitium_min POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory "$<TARGET_FILE_DIR:webkitium_min>"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${WEBKIT_RUNTIME_DLLS} "$<TARGET_FILE_DIR:webkitium_min>"
        COMMAND_EXPAND_LISTS
        VERBATIM
    )
endif()
