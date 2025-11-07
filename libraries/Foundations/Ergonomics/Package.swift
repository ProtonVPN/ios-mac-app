// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Ergonomics",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Ergonomics",
            targets: ["Ergonomics"]
        ),
        .library(
            name: "NetworkingErgonomics",
            targets: ["NetworkingErgonomics"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Ergonomics",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreServices", package: "protoncore"),
            ]
        ),
        .target(
            name: "NetworkingErgonomics",
            path: "Sources/Networking"
        ),
        .testTarget(
            name: "ErgonomicsTests",
            dependencies: [
                "Ergonomics",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "NetworkErgonomicsTests",
            dependencies: [
                "NetworkingErgonomics",
            ]
        ),
    ]
)
