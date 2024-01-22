// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"]
        )
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(path: "../Ergonomics")
    ],
    targets: [
        .target(
            name: "Theme",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                "Ergonomics",
            ],
            resources: [],
            plugins: []
        ),
    ]
)
