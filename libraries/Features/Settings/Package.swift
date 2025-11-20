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
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/CommonNetworking"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.6.0")),
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
                "Theme",
                "Strings",
                "Domain",
                "Ergonomics",
                "Localization",
                .product(name: "CommonNetworking", package: "CommonNetworking"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ],
            exclude: ["ObfuscatedConstants.example.swift"]
        ),
        .target(
            name: "Settings-iOS",
            dependencies: [
                "SettingsShared",
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
            ]
        ),
        .target(
            name: "Settings-macOS",
            dependencies: [
                "SettingsShared",
                .product(name: "SwiftNavigation", package: "swift-navigation"),
            ]
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
