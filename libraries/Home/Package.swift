// swift-tools-version: 5.7
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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.10.2"),
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../SharedViews"),
        .package(path: "../NetShield"),
        .package(path: "../Core/NEHelper"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
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
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            exclude: ["swiftgen.yml"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "Home",
                .product(name: "NetShield-iOS", package: "NetShield"),
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
            dependencies: ["Home", "Theme"]
        )
    ]
)
