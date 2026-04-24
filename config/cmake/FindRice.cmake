# Stub: librice (Rust ICE library) is not packaged for Ubuntu.
# Overrides WebKit's Source/cmake/FindRice.cmake so configure completes.
# Creates dummy imported targets with stub include path.
set(Rice_FOUND TRUE)
set(RICE_FOUND TRUE)

if (NOT TARGET Rice::Proto)
    add_library(Rice::Proto INTERFACE IMPORTED)
    set_target_properties(Rice::Proto PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/Source/ThirdParty/rice-stubs")
endif()
if (NOT TARGET Rice::Io)
    add_library(Rice::Io INTERFACE IMPORTED)
    set_target_properties(Rice::Io PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${CMAKE_SOURCE_DIR}/Source/ThirdParty/rice-stubs")
endif()
