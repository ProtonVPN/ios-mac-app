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
        .library(name: "CertificateAuthentication", targets: ["CertificateAuthentication"]),
        .library(name: "LocalAgent", targets: ["LocalAgent"]),
        .library(name: "Connection", targets: ["Connection"]),
        .library(name: "CoreConnection", targets: ["CoreConnection"]),
        .library(name: "ConnectionShared", targets: ["ConnectionShared"]), // Models shared between network extension and app targets
        .library(name: "Hermes", targets: ["Hermes"]),
        .library(name: "ConnectionTestSupport", targets: ["CoreConnectionTestSupport", "ConnectionTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"), // GoLibs

        .package(path: "../CommonNetworking"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.3.2")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.5.6")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
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
            ]
        ),
        .target(
            name: "CertificateAuthentication",
            dependencies: [
                "CoreConnection",
                "ExtensionIPC",
                "CommonNetworking",
                "Localization",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"), // VpnAuthKeychain
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
            ]
        ),
        .target(
            name: "LocalAgent",
            dependencies: [
                "CoreConnection",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "ExtensionManager",
            dependencies: [
                "CoreConnection",
                "Domain",
                "ExtensionIPC",
                "Localization",
                "Hermes",
                "CommonNetworking",
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Connection",
            dependencies: [
                "CertificateAuthentication",
                "ExtensionManager",
                "LocalAgent",
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
            name: "CertificateAuthenticationTests",
            dependencies: [
                "CertificateAuthentication",
                "CoreConnectionTestSupport",
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "LocalAgentTests",
            dependencies: [
                "LocalAgent",
                "Connection",
                .product(name: "DomainTestSupport", package: "Domain"),
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
