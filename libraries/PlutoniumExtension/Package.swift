// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlutoniumExtension",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "PlutoniumExtension",
            targets: ["PlutoniumExtension"]
        ),
    ],
    dependencies: [
        .package(path: "../Foundations/PMLogger"),
        .package(path: "../NEHelper"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/McNight/Besogne", .upToNextMajor(from: "0.0.1")),
    ],
    targets: [
        .target(
            name: "PlutoniumExtension",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "PMLogger",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "Besogne", package: "Besogne"),
            ]
        ),
        .testTarget(
            name: "PlutoniumExtensionTests",
            dependencies: ["PlutoniumExtension"]
        ),
    ]
)
