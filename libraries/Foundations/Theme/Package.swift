// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Theme",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Theme",
            targets: ["Theme"]
        ),
    ],
    dependencies: [
        .package(path: "../Ergonomics"),
        .package(path: "../PMLogger"),
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
    ],
    targets: [
        .target(
            name: "Theme",
            dependencies: [
                "Ergonomics",
                "PMLogger",
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "Logging", package: "swift-log"),
            ],
            exclude: ["swiftgen.yml"],
            resources: [.process("Resources")],
            plugins: []
        ),
    ]
)
