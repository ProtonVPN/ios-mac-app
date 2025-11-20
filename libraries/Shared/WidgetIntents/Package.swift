// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WidgetIntents",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "WidgetIntents",
            targets: ["WidgetIntents"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.6.2")),
        .package(path: "../../Connection"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Core/NEHelper"),
        .package(path: "../ConnectionInventory"),
    ],
    targets: [
        .target(
            name: "WidgetIntents",
            dependencies: [
                "Domain",
                "Connection",
                "ConnectionInventory",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "VPNAppCore", package: "NEHelper"),
            ]
        ),
        .testTarget(
            name: "WidgetIntentsTests",
            dependencies: ["WidgetIntents"]
        ),
    ]
)
