// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "webkitium-ios",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "webkitium-ios", targets: ["Webkitium"]),
    ],
    targets: [
        .executableTarget(
            name: "Webkitium",
            path: "Sources/Webkitium",
            resources: [.process("Resources")]
        ),
    ]
)
