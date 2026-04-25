// swift-tools-version: 5.9
//
// SwiftPM view of browser/webauthn/.  Spans browser/ (path: "..") so
// the target can pull in core/Origin.cpp alongside webauthn/*.cpp;
// public headers are scoped to webauthn/ so the module map resolves
// cleanly.

import PackageDescription

let package = Package(
    name: "WebkitiumWebAuthn",
    products: [
        .library(name: "WebkitiumWebAuthn", targets: ["WebkitiumWebAuthn"]),
    ],
    targets: [
        .target(
            name: "WebkitiumWebAuthn",
            path: "..",
            exclude: [
                "CMakeLists.txt",
                "SHELL_PLAN.md",
                "color",
                "extensions",
                "platform",
                "sync",
                "tabs",
                "tests",
                "third_party",
                "webnn",
            ],
            sources: [
                "core/Origin.cpp",
                "webauthn/WebAuthnBridgeC.cc",
                "webauthn/WebAuthnController.cpp",
            ],
            publicHeadersPath: "webauthn",
            cxxSettings: [
                .headerSearchPath("."),     // resolves "core/Origin.h" etc.
            ]
        ),
    ],
    cxxLanguageStandard: .cxx17
)
