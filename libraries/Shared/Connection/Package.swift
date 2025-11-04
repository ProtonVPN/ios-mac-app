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
        .library(name: "Hermes", targets: ["Hermes"]),
        .library(name: "ConnectionTestSupport", targets: ["CoreConnectionTestSupport", "ConnectionTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.3.2")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
        .package(path: "../../../external/protoncore"), // GoLibs
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../NEHelper"),
        .package(path: "../CommonNetworking"),
    ],
    targets: [
        .target(
            name: "CoreConnection",
            dependencies: [
                "Domain",
                "Ergonomics",
                "ExtensionIPC",
                "PMLogger",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                // Required for CustomDumpStringConvertible.
                .product(name: "CustomDump", package: "swift-custom-dump"),
            ]
        ),
        .target(
            name: "CertificateAuthentication",
            dependencies: [
                "CoreConnection",
                "ExtensionIPC",
                "CommonNetworking",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "VPNAppCore", package: "NEHelper"), // VpnAuthKeychain
            ]
        ),
        .target(
            name: "LocalAgent",
            dependencies: [
                "CoreConnection",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
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
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Connection",
            dependencies: [
                "Ergonomics",
                "Strings",
                "CertificateAuthentication",
                "ExtensionManager",
                "LocalAgent",
                "Localization",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "VPNAppCore", package: "NEHelper"),
            ]
        ),
        .target(
            name: "Hermes",
            dependencies: [
                "Domain",
                "Ergonomics",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(name: "CoreConnectionTestSupport", dependencies: ["CoreConnection"]),
        .target(name: "ConnectionTestSupport", dependencies: ["Connection", "CoreConnectionTestSupport"]),
        .testTarget(
            name: "ConnectionTests",
            dependencies: [
                "Connection",
                "CoreConnectionTestSupport",
                "ConnectionTestSupport",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "ExtensionManagerTests",
            dependencies: [
                "ExtensionManager",
                "CoreConnectionTestSupport",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "CertificateAuthenticationTests",
            dependencies: [
                "CertificateAuthentication",
                "CoreConnectionTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "LocalAgentTests",
            dependencies: [
                "LocalAgent",
                "Connection",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "HermesTests",
            dependencies: [
                "Hermes",
                "Connection",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
    ]
)
