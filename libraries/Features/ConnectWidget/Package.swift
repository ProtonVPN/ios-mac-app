// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectWidget",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "ConnectWidget",
            targets: ["ConnectWidget"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/ConnectionInventory"),
        .package(path: "../../Shared/WidgetIntents"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
    ],
    targets: [
        .target(
            name: "ConnectWidget",
            dependencies: [
                "Theme",
                "Strings",
                "Domain",
                "SharedViews",
                "ConnectionInventory",
                "WidgetIntents",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "OrderedCollections", package: "swift-collections"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ConnectWidgetTests",
            dependencies: ["ConnectWidget"]
        ),
    ]
)
