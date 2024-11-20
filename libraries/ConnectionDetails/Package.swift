// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionDetails",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],

    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ConnectionDetails",
            targets: ["ConnectionDetails"]),
        .library(
            name: "ConnectionDetails-iOS",
            targets: ["ConnectionDetails-iOS"]),
        .library(
            name: "ConnectionDetails-macOS",
            targets: ["ConnectionDetails-macOS"]),
    ],
    dependencies: [
        // Local
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Shared/Localization"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../SharedViews"),
        .package(path: "../NEHelper"),
        .package(path: "../../external/protoncore"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.15.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
    ],
    targets: [
        .target(
            name: "ConnectionDetails",
            dependencies: [
                "Localization",
                "Persistence",
                "Strings",
                "SharedViews",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "ConnectionDetails-iOS",
            dependencies: [
                "ConnectionDetails",
                "Persistence",
                "SharedViews",
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "Theme", package: "Theme"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ],
            resources: []
        ),
        .target(
            name: "ConnectionDetails-macOS",
            dependencies: [
                "ConnectionDetails",
                .product(name: "Theme", package: "Theme"),
            ],
            resources: []
        ),

        .testTarget(
            name: "ConnectionDetailsTests",
            dependencies: ["ConnectionDetails"]
        ),
    ]
)
