// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15)],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Theme",
            dependencies: [],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "ThemeTests",
            dependencies: ["Theme"]),
    ]
)
