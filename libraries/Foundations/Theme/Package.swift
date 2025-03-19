// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v16),
        .tvOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"]
        )
    ],
    dependencies: [
        .package(path: "../Ergonomics"),
        .package(path: "../PMLogger"),
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4"),
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
