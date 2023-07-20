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
        .package(path: "../Theme"),
        .package(path: "../SharedViews"),
        .package(path: "../NEHelper"),
        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "0.55.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths",
            exact: "0.14.1"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-snapshot-testing",
            exact: "1.10.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies.git",
            exact: "0.5.1"
        ),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "Theme",
                "Strings",
                "Ergonomics",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "Home",
                "SharedViews",
                "Strings",
                "Theme",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: []
        ),
        .target(
            name: "Home-macOS",
            dependencies: [
                "Home",
                "Theme",
                "SharedViews",
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: []
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: ["Home", "Theme"]
        )
    ]
)
