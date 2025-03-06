// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Home",
            targets: ["Home"]),
        .library(
            name: "Home-macOS",
            targets: ["Home-macOS"]),
        .library(
            name: "Home-iOS",
            targets: ["Home-iOS"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../SharedViews"),
        .package(path: "../NetShield"),
        .package(path: "../NEHelper"),
        .package(path: "../Shared/CommonNetworking"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Modals"),
        .package(path: "../ConnectionDetails"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "CommonNetworking",
                "Connection",
                "Persistence",
                "SharedViews",
                "NetShield",
                "Ergonomics",
                .product(name: "Modals", package: "Modals"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "ConnectionDetails", package: "ConnectionDetails"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "CombineSchedulers", package: "combine-schedulers")
            ],
            exclude: ["swiftgen.yml"],
            resources: [
                .process("Resources/BlankMap-World.svg")
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "Home",
                .product(name: "NetShield-iOS", package: "NetShield"),
                .product(name: "ConnectionDetails-iOS", package: "ConnectionDetails"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "Home-macOS",
            dependencies: [
                "Home",
                .product(name: "NetShield-macOS", package: "NetShield"),
            ],
            resources: []
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: [
                "Home",
                "Theme",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "HomeSnapshotTests",
            dependencies: [
                "Home",
                "Home-iOS",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        )
    ]
)
