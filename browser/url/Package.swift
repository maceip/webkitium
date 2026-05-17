// swift-tools-version: 5.9
//
// SwiftPM view of browser/url/. URL normalization + tracking-param scrubbing
// + search-engine URL builders. Consumed by the macOS shell via
// `.package(path: "../../browser/url")`. Mirrors browser/suggestions/Package.swift.

import PackageDescription

let package = Package(
    name: "WebkitiumUrl",
    products: [
        .library(name: "WebkitiumUrl", targets: ["WebkitiumUrl"]),
    ],
    targets: [
        .target(
            name: "WebkitiumUrl",
            path: ".",
            exclude: [
                "CMakeLists.txt",
            ],
            sources: [
                "UrlBridgeC.cc",
                "UrlNormalize.cpp",
            ],
            publicHeadersPath: "include",
            cxxSettings: [
                .headerSearchPath("."),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
