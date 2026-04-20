// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WebkitiumChrome",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "WebkitiumChrome", targets: ["WebkitiumChrome"])
    ],
    targets: [
        .executableTarget(name: "WebkitiumChrome")
    ]
)
