// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionDetails",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],

    products: [
        .library(
            name: "ConnectionDetails",
            targets: ["ConnectionDetails"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Core/SharedViews"),
        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Connection"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
    ],
    targets: [
        .target(
            name: "ConnectionDetails",
            dependencies: [
                .target(name: "ConnectionDetails-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "ConnectionDetails-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ConnectionDetailsShared",
            dependencies: [
                "Domain",
                "Localization",
                "Persistence",
                "Connection",
                "Strings",
                "SharedViews",
                "Theme",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "ConnectionDetails-iOS",
            dependencies: [
                "Connection",
                "ConnectionDetailsShared",
                "Theme",
            ],
            resources: []
        ),
        .target(
            name: "ConnectionDetails-macOS",
            dependencies: [
                "ConnectionDetailsShared",
                "Theme",
            ],
            resources: []
        ),

        .testTarget(
            name: "ConnectionDetailsTests",
            dependencies: [
                "ConnectionDetailsShared",
                .target(name: "ConnectionDetails-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "ConnectionDetails-macOS", condition: .when(platforms: [.macOS])),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
