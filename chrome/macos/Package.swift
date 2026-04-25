// swift-tools-version: 5.9
//
// Webkitium macOS shell.
//
// Depends on the four portable C ABI bridges in browser/:
//   - color/        palette generation (active)
//   - extensions/   ExtensionRegistry (wired-but-inactive)
//   - sync/         loopback sync surface (stub today)
//   - webauthn/     WebAuthnController (wired-but-inactive)

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
        .package(path: "../../browser/color"),
        .package(path: "../../browser/extensions"),
        .package(path: "../../browser/sync"),
        .package(path: "../../browser/webauthn"),
    ],
    targets: [
        .executableTarget(
            name: "Webkitium",
            dependencies: [
                .product(name: "WebkitiumColor",      package: "color"),
                .product(name: "WebkitiumExtensions", package: "extensions"),
                .product(name: "WebkitiumSync",       package: "sync"),
                .product(name: "WebkitiumWebAuthn",   package: "webauthn"),
            ],
            path: "Sources/Webkitium"
        ),
    ]
)
