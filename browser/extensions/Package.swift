// swift-tools-version: 5.9
//
// SwiftPM view of browser/extensions/.  Same shape as
// browser/color/Package.swift -- consumed by chrome/macos and
// chrome/ios via .package(path:).

import PackageDescription

let package = Package(
    name: "WebkitiumExtensions",
    products: [
        .library(name: "WebkitiumExtensions", targets: ["WebkitiumExtensions"]),
    ],
    targets: [
        .target(
            name: "WebkitiumExtensions",
            path: ".",
            exclude: [
                "README.md",
                "CMakeLists.txt",
            ],
            sources: [
                "ExtensionBridgeC.cc",
                "ExtensionManifest.cpp",
                "ExtensionRegistry.cpp",
            ],
            publicHeadersPath: "include",
            // Package-internal `extensions/` symlink subdir resolves the upstream
            // `#include "extensions/X.h"` style at the package root.
            cxxSettings: [
                .headerSearchPath("."),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
