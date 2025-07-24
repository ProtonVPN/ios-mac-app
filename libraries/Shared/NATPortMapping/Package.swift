// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NATPortMapping",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NATPortMapping",
            targets: ["NATPortMapping"]
        ),
    ],
    dependencies: [
        .package(path: "../../NEHelper"),
        .package(path: "../../Foundations/PMLogger"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.6.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "NATPortMapping",
            dependencies: [
                "PMLogger",
                .product(name: "VPNShared", package: "NEHelper"),
            ],
            path: "Sources/NATPortMapping"
        ),
        .executableTarget(
            name: "NATPortMapCLI",
            dependencies: [
                "NATPortMapping",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/CLI"
        ),
        .testTarget(
            name: "NATPortMappingTests",
            dependencies: ["NATPortMapping"]
        ),
    ]
)
