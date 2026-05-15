// swift-tools-version: 5.9
//
// SwiftPM view of browser/color/. Consumed by the macOS shell
// (chrome/macos/Package.swift) via `.package(path: "../../browser/color")`.
//
// This package does NOT replace the existing CMake build -- it sits next
// to it. Windows + CMake callers still use browser/CMakeLists.txt; macOS
// and iOS (future) consume the same sources through SPM. Both compile the
// same .cc/.cpp files.

import PackageDescription

let package = Package(
    name: "WebkitiumColor",
    products: [
        .library(name: "WebkitiumColor", targets: ["WebkitiumColor"]),
    ],
    targets: [
        .target(
            name: "WebkitiumColor",
            path: ".",
            exclude: [
                "README.md",
                "RAMP.md",
                "CMakeLists.txt",
            ],
            sources: [
                "ColorBridgeC.cc",
                "ColorRamp.cpp",
                "OklchColor.cpp",
                "SemanticPalette.cpp",
            ],
            publicHeadersPath: "include",
            // Package-internal `color/` symlink subdir resolves `#include "color/X.h"`
            // style at the package root, avoiding the `..` search path that
            // SwiftPM 5.10+ rejects as outside the package.
            cxxSettings: [
                .headerSearchPath("."),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
