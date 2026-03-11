// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "Payments",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Payments",
            targets: ["Payments"]
        ),
        .library(
            name: "PaymentsShared",
            targets: ["PaymentsShared"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Core/SharedViews"),
        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Persistence"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
    ],
    targets: [
        .target(
            name: "Payments",
            dependencies: [
                "PaymentsShared",
                .target(name: "Payments-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Payments-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "PaymentsShared",
            dependencies: [
                "Domain",
                "Strings",
                "CommonNetworking",
                "PMLogger",
                "SharedViews",
                "Theme",
                "Persistence",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "ProtonCorePaymentsV2", package: "protoncore"),
                .product(name: "ProtonCorePaymentsUIV2", package: "protoncore", condition: .when(platforms: [.iOS])),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Payments-iOS",
            dependencies: [
                "PaymentsShared",
                "Theme",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Payments-macOS",
            dependencies: [
                "PaymentsShared",
            ]
        ),
        .testTarget(
            name: "PaymentsTests",
            dependencies: [
                "PaymentsShared",
                .target(name: "Payments-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Payments-macOS", condition: .when(platforms: [.macOS])),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
    ]
)
