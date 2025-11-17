// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios_app",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ios_app",
            targets: ["ios_app"]
        ),
    ],
    dependencies: [
        .package(path: "../../NEHelper"),
        .package(path: "../../LegacyCommon"),
        .package(path: "../../Review"),
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ios_app",
            dependencies: [
                "LegacyCommon",
                "Review",
                "Theme",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [.process("Resources")],
        ),
        .testTarget(
            name: "ios_appTests",
            dependencies: ["ios_app"]
        ),
    ]
)
