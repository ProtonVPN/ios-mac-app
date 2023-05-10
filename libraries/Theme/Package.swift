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
    dependencies: [],
    targets: [
        .target(
            name: "Theme",
            dependencies: [],
            resources: [],
            plugins: []
        ),
        .target(
            name: "Theme-iOS",
            dependencies: ["Theme"],
            resources: []
        ),
        .target(
            name: "Theme-macOS",
            dependencies: ["Theme"],
            resources: []
        ),
        .testTarget(
            name: "ThemeTests",
            dependencies: ["Theme"]),
    ]
)
