// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Countries",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Countries",
            targets: ["Countries"]
        ),
    ],
    dependencies: [
        .package(path: "../Modals"),
        .package(path: "../Announcement"),
        .package(path: "../Payments"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/LegacyCommon"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/ConnectionInventory"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Localization"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
    ],
    targets: [
        .target(
            name: "Countries",
            dependencies: [
                .target(name: "Countries-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Countries-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "CountriesShared",
            dependencies: [
                "Connection",
                "ConnectionInventory",
                "LegacyCommon",
                "Theme",
                "CommonNetworking",
                "Domain",
                "Strings",
                "Modals",
                .product(name: "PaymentsShared", package: "Payments"),
                "Persistence",
                "Localization",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Countries-iOS",
            dependencies: [
                "CountriesShared",
                "Connection",
                "Modals",
                "SharedViews",
                "Domain",
                "Strings",
                "Persistence",
                "LegacyCommon",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Payments", package: "Payments"),
            ]
        ),
        .target(
            name: "Countries-macOS",
            dependencies: [
                "Announcement",
                "CountriesShared",
                "ConnectionInventory",
                .product(name: "Payments", package: "Payments"),
            ],
            resources: []
        ),
        .testTarget(
            name: "CountriesTests",
            dependencies: [
                "Connection",
                "CountriesShared",
                .target(name: "Countries-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Countries-macOS", condition: .when(platforms: [.macOS])),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),

                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
            ]
        ),
    ]
)
