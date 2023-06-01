// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)],
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
        .package(path: "../Theme"),
        .package(path: "../NEHelper"),
        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            branch: "prerelease/1.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            exact: "0.5.0"
        ),
        .package(
          url: "https://github.com/pointfreeco/swift-snapshot-testing",
          from: "1.10.0"
        ),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "Theme",
                "Strings",
                "Ergonomics",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "Home",
                "Strings",
                .product(name: "Theme-iOS", package: "Theme"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: []
        ),
        .target(
            name: "Home-macOS",
            dependencies: [
                "Home",
                .product(name: "Theme-macOS", package: "Theme"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: []
        )
    ]
)
