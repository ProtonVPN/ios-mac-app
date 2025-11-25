// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionDetails",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],

    products: [
        .library(
            name: "ConnectionDetails",
            targets: ["ConnectionDetails"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),

        .package(path: "../../Core/SharedViews"),
        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Connection"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        .target(
            name: "ConnectionDetails",
            dependencies: [
                .target(name: "ConnectionDetails-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "ConnectionDetails-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ConnectionDetailsShared",
            dependencies: [
                "Domain",
                "Localization",
                "Persistence",
                "Connection",
                "Strings",
                "SharedViews",
                "Theme",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "ConnectionDetails-iOS",
            dependencies: [
                "ConnectionDetailsShared",
            ],
            resources: []
        ),
        .target(
            name: "ConnectionDetails-macOS",
            dependencies: [
                "ConnectionDetailsShared",
            ],
            resources: []
        ),

        .testTarget(
            name: "ConnectionDetailsTests",
            dependencies: ["ConnectionDetailsShared"]
        ),
    ]
)
