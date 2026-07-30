// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LegacyCommon",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LegacyCommon",
            targets: ["LegacyCommon"]
        ),
    ],
    dependencies: [
        // External packages regularly upstreamed by our project (imported as submodules)
        .package(path: "../../../external/protoncore"),

        // Local packages
        .package(path: "../NEHelper"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/ConnectionInventory"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Telemetry"),

        // External dependencies

        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
    ],
    targets: [
        .target(
            name: "LegacyCommon",
            dependencies: [
                // Local
                "Domain",
                "Ergonomics",
                "Strings",
                "CommonNetworking",
                "Connection",
                "ConnectionInventory",
                "Telemetry",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Persistence", package: "Persistence"),
                .product(name: "CommonNetworkingTestSupport", package: "CommonNetworking"),

                // Core code
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCorePushNotifications", package: "protoncore"),
                .product(name: "ProtonCoreServices", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),

                // External
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "LegacyCommonTests",
            dependencies: [
                "LegacyCommon",
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "ProtonCoreTestingToolkitUnitTestsCore", package: "protoncore"),
            ]
        ),
    ]
)
