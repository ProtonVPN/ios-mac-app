// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
    ],
    dependencies: [
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../NEHelper"),
        .package(path: "../Shared/CommonNetworking"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.3.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                .target(name: "Settings-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Settings-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "SettingsShared",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                "Theme",
                "Strings",
                "CommonNetworking",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SwiftNavigation", package: "swift-navigation"),
            ],
            exclude: ["ObfuscatedConstants.example.swift"]
        ),
        .target(
            name: "Settings-iOS",
            dependencies: ["SettingsShared", .product(name: "SwiftNavigation", package: "swift-navigation")]
        ),
        .target(
            name: "Settings-macOS",
            dependencies: ["SettingsShared"]
        ),
        .testTarget(
            name: "SettingsTests",
            dependencies: [
                "Settings",
                "SettingsShared",
            ]
        ),
    ]
)
