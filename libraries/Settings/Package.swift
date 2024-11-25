// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [
        .iOS(.v16),
        .macOS(.v12)
    ],
    products: [
        .library(name: "Settings", targets: ["Settings"]),
        .library(name: "Settings-iOS", targets: ["Settings-iOS"]),
        .library(name: "Settings-macOS", targets: ["Settings-macOS"])
    ],
    dependencies: [
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Localization"),
        .package(path: "../NEHelper"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.15.1")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.2.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", exact: "1.4.1")
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                "Theme",
                "Localization",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftNavigation", package: "swift-navigation"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "Settings-iOS",
            dependencies: ["Settings"],
            exclude: ["swiftgen.yml"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Settings-macOS",
            dependencies: ["Settings"]
        ),
        .testTarget(name: "SettingsTests", dependencies: ["Settings"])
    ]
)
