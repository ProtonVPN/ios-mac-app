// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedViews",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SharedViews",
            targets: ["SharedViews"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../NEHelper"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),

        .package(path: "../../Shared/Localization"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
    ],
    targets: [
        .target(
            name: "SharedViews",
            dependencies: [
                .target(name: "SharedViews-macOS", condition: .when(platforms: [.macOS])),
                "Theme",
                "Ergonomics",
                "Strings",
                "Localization",
                "Domain",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .target(
            name: "SharedViews-macOS",
            dependencies: [
                "Theme",
                "Ergonomics",
            ],
            resources: []
        ),
    ]
)
