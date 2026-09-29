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
        .library(name: "Connection", targets: ["Connection"]),
        .library(name: "ExtensionManager", targets: ["ExtensionManager"]),
        .library(name: "CoreConnection", targets: ["CoreConnection"]),
        .library(name: "ConnectionShared", targets: ["ConnectionShared"]), // Models shared between network extension and app targets
        .library(name: "IPCDefinitions", targets: ["IPCDefinitions"]),
        .library(name: "ExtensionSync", targets: ["ExtensionSync"]),
        .library(name: "Hermes", targets: ["Hermes"]),
        .library(name: "ConnectionTestSupport", targets: ["CoreConnectionTestSupport", "ConnectionTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/vpn-core-apple"),
        .package(path: "../../../external/protoncore"),

        .package(path: "../CommonNetworking"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/WidgetReload"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.6.1")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.5.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
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
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                "PMLogger",
                "ExtensionIPC",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"), // Sentry
                .product(name: "CasePaths", package: "swift-case-paths"),
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
                .product(name: "VPNCoreTypes", package: "vpn-core-apple"),
                .product(name: "VPNCoreCommon", package: "vpn-core-apple"),
            ]
        ),
        .target(
            name: "IPCDefinitions",
            dependencies: [
                .product(name: "IPCSeqlockHelpers", package: "Ergonomics"),
            ],
            path: "Sources/IPCDefinitions",
            publicHeadersPath: "include"
        ),
        .target(
            name: "ExtensionSync",
            dependencies: [
                "IPCDefinitions",
                "CoreConnection",
                .product(name: "IPCErgonomics", package: "Ergonomics"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "ExtensionManager",
            dependencies: [
                "CoreConnection",
                "Domain",
                "ExtensionIPC",
                "ExtensionSync",
                "Localization",
                "Hermes",
                "CommonNetworking",
                "Strings",
                .product(name: "SharedErgonomics", package: "Ergonomics"),
                .product(name: "VPNCoreTypes", package: "vpn-core-apple"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IPCErgonomics", package: "Ergonomics"),
            ]
        ),
        .target(
            name: "Connection",
            dependencies: [
                "ExtensionManager",
                "WidgetReload",
                "IPCDefinitions",
                "Domain",
                "Localization",
                "ExtensionSync",
                "CommonNetworking",
                "Strings",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Hermes",
            dependencies: [
                "Domain",
                "Ergonomics",
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .target(
            name: "CoreConnectionTestSupport",
            dependencies: [
                "CoreConnection",
                "ExtensionIPC",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "ConnectionTestSupport",
            dependencies: [
                "Connection",
                "CoreConnectionTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "ConnectionTests",
            dependencies: [
                "Connection",
                "CoreConnectionTestSupport",
                "ConnectionTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNShared", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "ExtensionManagerTests",
            dependencies: [
                "ExtensionManager",
                "ExtensionSync",
                "ConnectionShared",
                "CoreConnectionTestSupport",
                .product(name: "SharedErgonomics", package: "Ergonomics"),
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
