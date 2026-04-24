# Stub: librice (Rust ICE library) is not packaged for Ubuntu.
# Overrides WebKit's Source/cmake/FindRice.cmake so configure completes.
# Creates dummy imported targets so target_link_libraries doesn't fail.
set(Rice_FOUND TRUE)
set(RICE_FOUND TRUE)

if (NOT TARGET Rice::Proto)
    add_library(Rice::Proto INTERFACE IMPORTED)
endif()
if (NOT TARGET Rice::Io)
    add_library(Rice::Io INTERFACE IMPORTED)
endif()
