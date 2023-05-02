// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"]),
        .library(
            name: "Theme-macOS",
            targets: ["Theme-macOS"]),
        .library(
            name: "Theme-iOS",
            targets: ["Theme-iOS"])
    ],
    dependencies: [.package(url: "https://github.com/SwiftGen/SwiftGenPlugin", from: "6.6.0")],
    targets: [
        .target(
            name: "Theme",
            dependencies: [],
            resources: [],
            plugins: [
              .plugin(name: "SwiftGenPlugin", package: "SwiftGenPlugin")
            ]
        ),
        .target(
            name: "Theme-iOS",
            dependencies: ["Theme"],
            resources: []
        ),
        .target(
            name: "Theme-macOS",
            dependencies: ["Theme"],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "ThemeTests",
            dependencies: ["Theme"]),
    ]
)
