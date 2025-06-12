// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionDetails",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],

    products: [
        .library(
            name: "ConnectionDetails",
            targets: ["ConnectionDetails"]),
    ],
    dependencies: [
        // Local
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Shared/Localization"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Shared/Connection"),
        .package(path: "../SharedViews"),
        .package(path: "../NEHelper"),
        .package(path: "../../external/protoncore"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
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
                "Localization",
                "Persistence",
                "Connection",
                "Strings",
                "SharedViews",
                "Theme",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
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
            dependencies: ["ConnectionDetails"]
        ),
    ]
)
