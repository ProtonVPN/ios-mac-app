// swift-tools-version: 6.1
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
        .package(path: "../ConnectionInventory"),
        .package(path: "../Connection"),
        .package(path: "../Localization"),
        .package(path: "../Persistence"),
        .package(path: "../Strings"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/apple/swift-log", .upToNextMajor(from: "1.6.2")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
    ],
    targets: [
        .target(
            name: "WidgetIntents",
            dependencies: [
                "Domain",
                "Ergonomics",
                "Connection",
                "ConnectionInventory",
                "Localization",
                "Persistence",
                "Strings",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .testTarget(
            name: "WidgetIntentsTests",
            dependencies: ["WidgetIntents"]
        ),
    ]
)
