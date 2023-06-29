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
            from: "0.55.0"
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths",
            from: "0.14.1"
        ),
        .package(
          url: "https://github.com/pointfreeco/swift-snapshot-testing",
          from: "1.10.0"
        ),
        .package(
          url: "https://github.com/pointfreeco/swift-dependencies.git",
          from: "0.5.1"
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
                "Strings",
                .product(name: "Theme-macOS", package: "Theme"),
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
