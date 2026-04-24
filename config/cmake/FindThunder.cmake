# Stub: Thunder (WPE/RDK framework) is not installed on this runner.
# Overrides WebKit's Source/cmake/FindThunder.cmake so configure
# completes. ENABLE_THUNDER=OFF ensures nothing links against it.
set(THUNDER_FOUND TRUE)
set(Thunder_FOUND TRUE)
set(THUNDER_INCLUDE_DIR "/usr/include")
set(THUNDER_LIBRARY "")
