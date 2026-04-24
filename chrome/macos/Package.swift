// swift-tools-version: 5.9
//
// Webkitium macOS shell.
//
// Single executable target that depends on the portable color library
// rooted at browser/color/. No other external dependencies; no CocoaPods,
// no Homebrew. `swift run webkitium` works from a clean checkout.

import PackageDescription

let package = Package(
    name: "webkitium",
    platforms: [
        .macOS(.v14),  // macOS 14 Sonoma minimum; Liquid Glass is macOS 26
    ],
    products: [
        .executable(name: "webkitium", targets: ["Webkitium"]),
    ],
    dependencies: [
        // Same C++ sources the Windows CMake build compiles. One
        // algorithm, three platforms.
        .package(path: "../../browser/color"),
    ],
    targets: [
        .executableTarget(
            name: "Webkitium",
            dependencies: [
                .product(name: "WebkitiumColor", package: "color"),
            ],
            path: "Sources/Webkitium"
        ),
    ]
)
