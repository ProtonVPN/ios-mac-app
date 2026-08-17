// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectWidget",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "ConnectWidget",
            targets: ["ConnectWidget"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/ConnectionInventory"),
        .package(path: "../../Shared/WidgetIntents"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
    ],
    targets: [
        .target(
            name: "ConnectWidget",
            dependencies: [
                "Theme",
                "Strings",
                "Domain",
                "SharedViews",
                "Connection",
                "ConnectionInventory",
                "WidgetIntents",
                .product(name: "ExtensionSync", package: "Connection"),
                .product(name: "CoreConnection", package: "Connection"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "OrderedCollections", package: "swift-collections"),
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
