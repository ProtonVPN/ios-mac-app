// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionInventory",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ConnectionInventory",
            targets: ["ConnectionInventory"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(path: "../../SharedViews"),
        .package(path: "../../Foundations/Domain"),
    ],
    targets: [
        .target(
            name: "ConnectionInventory",
            dependencies: [
                "Domain",
                "SharedViews",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
            ]
        ),
        .testTarget(
            name: "ConnectionInventoryTests",
            dependencies: ["ConnectionInventory"]
        ),
    ]
)
