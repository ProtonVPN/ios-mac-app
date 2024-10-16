// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
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
        .package(url: "https://github.com/apple/swift-collections.git", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.13.1")),
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../SharedViews"),
        .package(path: "../NetShield"),
        .package(path: "../Core/NEHelper"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Features/Modals"),
        .package(path: "../Features/ConnectionDetails"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "Theme",
                "Strings",
                "Ergonomics",
                "Connection",
                "Persistence",
                "SharedViews",
                "NetShield",
                "Modals",
                .product(name: "ConnectionDetails", package: "ConnectionDetails"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "Collections", package: "swift-collections"),
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
            ],
            resources: []
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
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        )
    ]
)
