// swift-tools-version: 5.9
//
// SwiftPM view of browser/sync/.  Wired-but-inactive: only the stub
// SyncBridgeC.cc compiles for shells today.  When sync is activated
// the sources list expands to include LoopbackSyncServer + protobuf
// generated wire types.

import PackageDescription

let package = Package(
    name: "WebkitiumSync",
    products: [
        .library(name: "WebkitiumSync", targets: ["WebkitiumSync"]),
    ],
    targets: [
        .target(
            name: "WebkitiumSync",
            path: ".",
            exclude: [
                "README.md",
                "CMakeLists.txt",
            ],
            sources: [
                "SyncBridgeC.cc",
            ],
            publicHeadersPath: ".",
            cxxSettings: [
                .headerSearchPath(".."),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
