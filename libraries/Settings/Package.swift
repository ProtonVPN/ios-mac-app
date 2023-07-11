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
        .package(path: "../Theme"),
        .package(path: "../Strings"),
        .package(path: "../NEHelper"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "0.55.0"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", exact: "0.8.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", exact: "0.5.1")
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                "Theme",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "Settings-iOS",
            dependencies: ["Settings"]
        ),
        .target(
            name: "Settings-macOS",
            dependencies: ["Settings"]
        ),
        .testTarget(name: "SettingsTests", dependencies: ["Settings"])
    ]
)
