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
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../SharedViews"),
        .package(path: "../NEHelper"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Ergonomics"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.10.2"),
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths",
            exact: "1.3.0"
        ),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", exact: "1.2.2"),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                "Theme",
                "Strings",
                "Ergonomics",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
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
