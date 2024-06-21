// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Connection",
    platforms: [
        .iOS(.v16),
        .macOS(.v12),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "CertificateAuthentication", targets: ["CertificateAuthentication"]),
        .library(name: "LocalAgent", targets: ["LocalAgent"]),
        .library(name: "Connection", targets: ["Connection"]),
        .library(name: "ConnectionTestSupport", targets: ["LocalAgentTestSupport"]),
        .library(name: "ConnectionFoundations", targets: ["ConnectionFoundations"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.10.2")),
        .package(path: "../../../external/protoncore"), // GoLibs
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../NEHelper"),
    ],
    targets: [
        .target(
            name: "ConnectionFoundations",
            dependencies: [
                "Domain",
                "Ergonomics",
                "ExtensionIPC",
                "PMLogger",
                "ExtensionIPC",
                .product(name: "VPNShared", package: "NEHelper"),
            ]
        ),
        .target(
            name: "CertificateAuthentication",
            dependencies: [
                "ConnectionFoundations",
                "ExtensionIPC",
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "VPNAppCore", package: "NEHelper"), // VpnAuthKeychain
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "LocalAgent",
            dependencies: [
                "ConnectionFoundations",
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "ExtensionManager",
            dependencies: [
                "ConnectionFoundations",
                "Domain",
                "ExtensionIPC",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Connection",
            dependencies: [
                "CertificateAuthentication",
                "ExtensionManager",
                "LocalAgent",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(name: "ConnectionFoundationsTestSupport", dependencies: ["ConnectionFoundations"]),
        .target(name: "LocalAgentTestSupport", dependencies: ["LocalAgent"]),
        .testTarget(
            name: "ConnectionTests",
            dependencies: [
                "Connection",
                "LocalAgentTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "ExtensionManagerTests",
            dependencies: [
                "ExtensionManager",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "CertificateAuthenticationTests",
            dependencies: [
                "CertificateAuthentication",
                "ConnectionFoundationsTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "LocalAgentTests",
            dependencies: [
                "LocalAgent",
                "LocalAgentTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
    ]
)
