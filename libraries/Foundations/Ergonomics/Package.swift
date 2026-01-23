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
        .library(
            name: "SharedErgonomics",
            targets: ["SharedErgonomics"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            .upToNextMajor(from: "1.23.1")
        ),
        .package(
            url: "https://github.com/pointfreeco/xctest-dynamic-overlay",
            .upToNextMajor(from: "1.7.0")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-concurrency-extras",
            .upToNextMajor(from: "1.3.1")
        ),
        .package(
            url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.0")
        ),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(
            url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")
        ),
        .package(url: "https://github.com/mxcl/Version", exact: "2.1.0"),
    ],
    targets: [
        // Super lightweight helpers and dependencies shared between app and network extension targets
        .target(
            name: "SharedErgonomics",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            path: "Sources/Shared"
        ),
        .target(
            name: "Ergonomics",
            dependencies: [
                "Version",
                "SharedErgonomics",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Sharing", package: "swift-sharing"),
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
                "Version",
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
