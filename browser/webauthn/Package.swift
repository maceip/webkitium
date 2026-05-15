// swift-tools-version: 5.9
//
// SwiftPM view of browser/webauthn/. Package root is `.` (browser/webauthn/);
// `core/Origin.{h,cpp}` is reachable via a package-internal `core/` symlink
// folder so we can stay within the package root that SwiftPM 5.10+ enforces.

import PackageDescription

let package = Package(
    name: "WebkitiumWebAuthn",
    products: [
        .library(name: "WebkitiumWebAuthn", targets: ["WebkitiumWebAuthn"]),
    ],
    targets: [
        .target(
            name: "WebkitiumWebAuthn",
            path: ".",
            exclude: [
                "README.md",
                "CMakeLists.txt",
            ],
            sources: [
                "WebAuthnBridgeC.cc",
                "WebAuthnController.cpp",
                "core/Origin.cpp",          // symlinked from ../core/Origin.cpp
            ],
            publicHeadersPath: "include",
            // The package-internal `webauthn/` + `core/` symlink folders resolve
            // `#include "webauthn/X.h"` and `#include "core/Origin.h"` against the
            // package root.
            cxxSettings: [
                .headerSearchPath("."),
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
