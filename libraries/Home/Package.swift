// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)],
    products: [
        .library(
            name: "Home",
            targets: ["Home"]),
        .library(
            name: "Home-macOS",
            targets: ["Home-macOS"]),
        .library(
            name: "Home-iOS",
            targets: ["Home-iOS"])
    ],
    dependencies: [
        .package(path: "../Theme")
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: ["Home", .product(name: "Theme-iOS", package: "Theme")],
            resources: []
        ),
        .target(
            name: "Home-macOS",
            dependencies: ["Home", .product(name: "Theme-macOS", package: "Theme")],
            resources: []
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: ["Home"]),
    ]
)
