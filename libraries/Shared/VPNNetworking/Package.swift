// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VPNNetworking",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "VPNNetworking",
            targets: ["VPNNetworking"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Strings"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
    ],
    targets: [
        .target(
            name: "VPNNetworking",
            dependencies: [
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "VPNNetworkingTests",
            dependencies: ["VPNNetworking"]
        ),
    ]
)
