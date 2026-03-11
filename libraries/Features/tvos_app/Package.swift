// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tvos_app",
    defaultLocalization: "en",
    platforms: [
        .tvOS(.v17),
    ],
    products: [
        .library(name: "tvos_app", targets: ["tvos_app"]),
        .library(name: "tvOSTestSupport", targets: ["tvOSTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Modals"),
        .package(path: "../Payments"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Persistence"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.5.6")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
        .package(url: "https://github.com/ProxymanApp/atlantis", .upToNextMajor(from: "1.34.0")),
    ],
    targets: [
        .target(
            name: "tvos_app",
            dependencies: [
                "Theme",
                "Localization",
                "CommonNetworking",
                "Connection",
                "Persistence",
                "Payments",

                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "SharedErgonomics", package: "Ergonomics"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "VPNShared", package: "NEHelper"), // AuthKeychain

                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "ProtonCoreChallenge", package: "protoncore"),
                .product(name: "ProtonCoreForceUpgrade", package: "protoncore"),
                .product(name: "ProtonCoreFoundations", package: "protoncore"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCorePaymentsV2", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ProtonCoreServices", package: "protoncore"),
                .product(name: "ProtonCoreAPIClient", package: "protoncore"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Atlantis", package: "atlantis"),
            ],
            exclude: ["Resources/ObfuscatedConstants.example.swift"],
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .target(
            name: "tvOSTestSupport",
            dependencies: ["tvos_app"]
        ),
        .testTarget(
            name: "tvos_appTests",
            dependencies: [
                "tvos_app",
                "tvOSTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ConnectionTestSupport", package: "Connection"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
            ]
        ),
        .testTarget(
            name: "tvos_appSnapshotTests",
            dependencies: [
                "tvos_app",
                "tvOSTestSupport",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ConnectionTestSupport", package: "Connection"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            resources: [.copy("Resources/ApplicationLogs_tvOS.log")]
        ),
    ]
)
