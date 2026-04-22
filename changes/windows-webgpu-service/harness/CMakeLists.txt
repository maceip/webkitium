cmake_minimum_required(VERSION 3.21)
project(webgpu_host LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if (NOT WIN32)
    message(FATAL_ERROR "webgpu_host is Windows-only (HWND surface + D3D12).")
endif()

# Dawn: try vcpkg config package first, then fall back to bare
# webgpu_dawn.{dll,lib} + webgpu/webgpu.h under DAWN_ROOT.
set(WEBGPU_HOST_DAWN_TARGET "")

find_package(Dawn CONFIG QUIET)
if (TARGET Dawn::webgpu_dawn)
    set(WEBGPU_HOST_DAWN_TARGET Dawn::webgpu_dawn)
elseif (TARGET dawn::webgpu_dawn)
    set(WEBGPU_HOST_DAWN_TARGET dawn::webgpu_dawn)
elseif (TARGET webgpu_dawn)
    set(WEBGPU_HOST_DAWN_TARGET webgpu_dawn)
endif()

if (NOT WEBGPU_HOST_DAWN_TARGET)
    # Manual fallback. Mirrors the pattern in
    # webkit/patches/windows/0023-windows-enable-webgpu-dawn.patch
    # (FindDawn.cmake fallback for `dawn/dawn_proc_table.h` + `webgpu_dawn`).
    find_path(DAWN_INCLUDE_DIR
        NAMES webgpu/webgpu.h
        HINTS "${DAWN_ROOT}/include" "$ENV{VCPKG_ROOT}/installed/x64-windows/include"
              "$ENV{VCPKG_ROOT}/installed/x64-windows-webkit/include"
    )
    find_library(DAWN_LIBRARY
        NAMES webgpu_dawn
        HINTS "${DAWN_ROOT}/lib" "$ENV{VCPKG_ROOT}/installed/x64-windows/lib"
              "$ENV{VCPKG_ROOT}/installed/x64-windows-webkit/lib"
    )
    find_file(DAWN_DLL
        NAMES webgpu_dawn.dll
        HINTS "${DAWN_ROOT}/bin" "$ENV{VCPKG_ROOT}/installed/x64-windows/bin"
              "$ENV{VCPKG_ROOT}/installed/x64-windows-webkit/bin"
    )
    if (NOT DAWN_INCLUDE_DIR OR NOT DAWN_LIBRARY)
        message(FATAL_ERROR
            "Dawn not found. Install via vcpkg (webgpu_dawn) and pass "
            "-DCMAKE_TOOLCHAIN_FILE=<vcpkg>/scripts/buildsystems/vcpkg.cmake, "
            "or set -DDAWN_ROOT=<path containing include/ lib/ bin/>.")
    endif()
    add_library(webgpu_host_dawn INTERFACE)
    target_include_directories(webgpu_host_dawn INTERFACE "${DAWN_INCLUDE_DIR}")
    target_link_libraries(webgpu_host_dawn INTERFACE "${DAWN_LIBRARY}")
    set(WEBGPU_HOST_DAWN_TARGET webgpu_host_dawn)
endif()

add_executable(webgpu_host WIN32
    src/main.cpp
    src/dawn_bootstrap.cpp
    src/surface.cpp
    src/scene_bouncing_ball.cpp
    src/scene_triangle.cpp
    src/probe.cpp
    src/probe_adapter_info.cpp
    src/probe_buffer_readback.cpp
    src/probe_compute_smoke.cpp
    src/probe_error_callback.cpp
    src/probe_surface_roundtrip.cpp
    src/probe_render_offscreen.cpp
    src/probe_suite.cpp
)

target_include_directories(webgpu_host PRIVATE include)
target_link_libraries(webgpu_host PRIVATE ${WEBGPU_HOST_DAWN_TARGET} user32 gdi32 dxgi)
target_compile_definitions(webgpu_host PRIVATE
    NOMINMAX
    WIN32_LEAN_AND_MEAN
    UNICODE _UNICODE
    WEBGPU_SKIP_PROCTABLE=1
)

if (MSVC)
    target_compile_options(webgpu_host PRIVATE /W4 /permissive- /Zc:preprocessor)
endif()

# Copy Dawn runtime DLLs beside the exe so the binary launches from the build
# tree. Matches the packaging rule in webgpu-dawn-runbook.md (use whichever
# abseil_dll.dll matches webgpu_dawn.dll).
if (DAWN_DLL)
    add_custom_command(TARGET webgpu_host POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "${DAWN_DLL}" "$<TARGET_FILE_DIR:webgpu_host>/webgpu_dawn.dll"
    )
    get_filename_component(DAWN_DLL_DIR "${DAWN_DLL}" DIRECTORY)
    set(ABSEIL_DLL "${DAWN_DLL_DIR}/abseil_dll.dll")
    if (EXISTS "${ABSEIL_DLL}")
        add_custom_command(TARGET webgpu_host POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${ABSEIL_DLL}" "$<TARGET_FILE_DIR:webgpu_host>/abseil_dll.dll"
        )
    endif()
endif()
