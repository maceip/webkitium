// swift-tools-version: 5.9
//
// SwiftPM view of browser/suggestions/. Consumed by the macOS shell
// (chrome/macos/Package.swift) via `.package(path: "../../browser/suggestions")`.
//
// Mirrors browser/color/Package.swift's pattern. CMake build sits next to
// this; both compile the same .cc/.cpp.

import PackageDescription

let package = Package(
    name: "WebkitiumSuggestions",
    products: [
        .library(name: "WebkitiumSuggestions", targets: ["WebkitiumSuggestions"]),
    ],
    targets: [
        .target(
            name: "WebkitiumSuggestions",
            path: ".",
            exclude: [
                "CMakeLists.txt",
            ],
            sources: [
                "SuggestionsBridgeC.cc",
                "SuggestionIndex.cpp",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
