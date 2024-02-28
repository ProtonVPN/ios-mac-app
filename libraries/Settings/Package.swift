// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.iOS(.v15), .macOS(.v11)],
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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", exact: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", exact: "1.2.1")
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
                .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
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
