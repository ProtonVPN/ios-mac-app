// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v17)],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"]
        )
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(path: "../Ergonomics"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4"),
        .package(path: "../PMLogger"),
    ],
    targets: [
        .target(
            name: "Theme",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                "Ergonomics",
                "PMLogger",
                .product(name: "Logging", package: "swift-log")
            ],
            exclude: ["swiftgen.yml"],
            resources: [.process("Resources")],
            plugins: []
        ),
    ]
)
