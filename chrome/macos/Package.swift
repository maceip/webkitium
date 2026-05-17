// swift-tools-version: 6.2
//
// Webkitium macOS shell.
//
// SwiftUI + AppKit + Liquid Glass (macOS 26 Tahoe). Depends on portable
// C ABI bridges in browser/:
//   - color/        palette generation (active)
//   - extensions/   ExtensionRegistry (wired-but-inactive)
//   - suggestions/  URL-bar autocomplete (SQLite FTS5, active)
//   - sync/         loopback sync surface (stub today)
//   - url/          URL normalization + search-engine routing (active)
//   - webauthn/     WebAuthnController (wired-but-inactive)
//
// macOS 26 is required (not just recommended) because the chrome relies on the
// `.glassEffect(_:in:)` SwiftUI API and the macOS 26 `@Observable`-tracked
// NavigationSplitView semantics. swift-tools-version 6.2 is the minimum that
// understands the macOS 26 platform identifier in PackageDescription.

import PackageDescription

let package = Package(
    name: "webkitium",
    platforms: [
        .macOS(.v26),
    ],
    products: [
        .executable(name: "webkitium", targets: ["Webkitium"]),
    ],
    dependencies: [
        .package(path: "../../browser/color"),
        .package(path: "../../browser/extensions"),
        .package(path: "../../browser/suggestions"),
        .package(path: "../../browser/sync"),
        .package(path: "../../browser/url"),
        .package(path: "../../browser/webauthn"),
    ],
    targets: [
        .executableTarget(
            name: "Webkitium",
            dependencies: [
                .product(name: "WebkitiumColor",        package: "color"),
                .product(name: "WebkitiumExtensions",   package: "extensions"),
                .product(name: "WebkitiumSuggestions",  package: "suggestions"),
                .product(name: "WebkitiumSync",         package: "sync"),
                .product(name: "WebkitiumUrl",          package: "url"),
                .product(name: "WebkitiumWebAuthn",     package: "webauthn"),
            ],
            path: "Sources/Webkitium"
        ),
    ]
)
