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
            name: "IPCErgonomics",
            targets: ["IPCErgonomics"]
        ),
        .library(
            name: "SharedErgonomics",
            targets: ["SharedErgonomics"]
        ),
        .library(
            name: "TestingErgonomics",
            targets: ["TestingErgonomics"]
        ),
        .library(
            name: "Triangulation",
            targets: ["Triangulation"]
        ),
        .library(
            name: "IPCSeqlockHelpers",
            targets: ["IPCSeqlockHelpers"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            .upToNextMajor(from: "1.24.1")
        ),
        .package(
            url: "https://github.com/pointfreeco/xctest-dynamic-overlay",
            .upToNextMajor(from: "1.9.0")
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
            url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")
        ),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.3.0")),
        .package(url: "https://github.com/mxcl/Version", exact: "2.1.0"),
    ],
    targets: [
        // Super lightweight helpers and dependencies shared between app and network extension targets
        .target(
            name: "SharedErgonomics",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
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
            ],
            swiftSettings: [
                // BinaryDecoder stores its RawSpan cursor and mutates through ~Escapable self, which is SE-0446's
                // still-experimental lifetime-dependence slice (@_lifetime). Consuming modules conform and call
                // through stable syntax.
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        .target(
            name: "NetworkingErgonomics",
            dependencies: ["Ergonomics"],
            path: "Sources/Networking"
        ),
        .target(
            name: "IPCSeqlockHelpers",
            path: "Sources/IPC/SeqlockHelpers",
            publicHeadersPath: "include"
        ),
        .target(
            name: "IPCErgonomics",
            dependencies: [
                "Ergonomics",
                "IPCSeqlockHelpers",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ],
            path: "Sources/IPC/Library"
        ),
        .target(
            name: "IPCErgonomicsTestSupport",
            dependencies: ["IPCSeqlockHelpers"],
            path: "Sources/IPC/TestSupport",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Triangulation",
            path: "Sources/Triangulation"
        ),
        .target(
            name: "TestingErgonomics",
            dependencies: [
                "Triangulation", // dump conformances for the geometry types tests assert on
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            path: "Sources/Testing"
        ),
        .testTarget(
            name: "ErgonomicsTests",
            dependencies: [
                "Ergonomics",
                "Triangulation", // NaturalEarthTests exercises the shared projection directly
                "Version",
                .product(name: "Clocks", package: "swift-clocks"),
                // Test targets link DependenciesTestSupport (which re-exports Dependencies), never
                // Dependencies directly, so the `.dependencies` suite trait is available everywhere.
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "IPCErgonomicsTests",
            dependencies: [
                "IPCErgonomics",
                "IPCSeqlockHelpers",
                "IPCErgonomicsTestSupport",
            ]
        ),
        .testTarget(
            name: "NetworkErgonomicsTests",
            dependencies: [
                "NetworkingErgonomics",
            ]
        ),
        .testTarget(
            name: "SharedErgonomicsTests",
            dependencies: [
                "SharedErgonomics",
            ]
        ),
    ]
)
