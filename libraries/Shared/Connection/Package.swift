// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Connection",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "LocalAgent", targets: ["LocalAgent"]),
        .library(name: "LocalAgentIPC", targets: ["LocalAgentIPC"]),
        .library(name: "Connection", targets: ["Connection"]),
        .library(name: "CoreConnection", targets: ["CoreConnection"]),
        .library(name: "ConnectionShared", targets: ["ConnectionShared"]), // Models shared between network extension and app targets
        .library(name: "Hermes", targets: ["Hermes"]),
        .library(name: "ConnectionTestSupport", targets: ["CoreConnectionTestSupport", "ConnectionTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/vpn-core-apple"),
        .package(path: "../../../external/protoncore"),

        .package(path: "../CommonNetworking"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.5.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.9.0")),
    ],
    targets: [
        .target(
            name: "CoreConnection",
            dependencies: [
                "ConnectionShared",
                "Domain",
                "Ergonomics",
                "PMLogger",
                "ExtensionIPC",
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"), // Temporary
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"), // Sentry
                // Required for CustomDumpStringConvertible.
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        // Ultra-lightweight target containing models shared between app and network extension.
        .target(
            name: "ConnectionShared",
            dependencies: [
                "Domain",
                .product(name: "SharedErgonomics", package: "Ergonomics"),
                .product(name: "VPNCore", package: "vpn-core-apple"),
            ]
        ),
        .target(
            name: "LocalAgent",
            dependencies: [
                "CoreConnection",
                "LocalAgentIPC",
                .product(name: "IPCErgonomics", package: "Ergonomics"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "LocalAgentIPC",
            dependencies: [
                .product(name: "IPCSeqlockHelpers", package: "Ergonomics"),
            ],
            path: "Sources/LocalAgentIPC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "ExtensionManager",
            dependencies: [
                "LocalAgent",
                "CoreConnection",
                "Domain",
                "ExtensionIPC",
                "Localization",
                "Hermes",
                "CommonNetworking",
                .product(name: "VPNCore", package: "vpn-core-apple"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Connection",
            dependencies: [
                "ExtensionManager",
                "LocalAgent",
                "Domain",
                "Localization",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IPCErgonomics", package: "Ergonomics"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "Hermes",
            dependencies: [
                "Domain",
                "Ergonomics",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .target(
            name: "CoreConnectionTestSupport",
            dependencies: [
                "CoreConnection",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .target(
            name: "ConnectionTestSupport",
            dependencies: [
                "Connection",
                "CoreConnectionTestSupport",
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "ConnectionTests",
            dependencies: [
                "Connection",
                "CoreConnectionTestSupport",
                "ConnectionTestSupport",
            ]
        ),
        .testTarget(
            name: "ExtensionManagerTests",
            dependencies: [
                "ExtensionManager",
                "CoreConnectionTestSupport",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "HermesTests",
            dependencies: [
                "Hermes",
                "Connection",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
    ]
)
