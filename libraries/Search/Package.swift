// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    defaultLocalization: "en",
    platforms: [.iOS(.v12)],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [],
            resources: [
                .process("Storyboard.storyboard")
            ])
    ]
)
