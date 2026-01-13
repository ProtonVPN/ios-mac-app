// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NEHelper",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "NEHelper", targets: ["NEHelper"]),
        .library(name: "VPNAppCore", targets: ["VPNAppCore"]),
        .library(name: "VPNShared", targets: ["VPNShared"]),
        .library(name: "VPNCrypto", targets: ["VPNCrypto"]),
        .library(name: "VPNSharedTesting", targets: ["VPNSharedTesting"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Timer"),

        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/ExtensionIPC"),

        .package(path: "../../Features/NetShield"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "4.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.6.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", .upToNextMajor(from: "1.3.1")),
        .package(url: "https://github.com/getsentry/sentry-cocoa", exact: "9.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
    ],
    targets: [
        .target(
            name: "VPNShared",
            dependencies: [
                "Domain",
                "ExtensionIPC",
                "VPNCrypto",
                "Strings",
                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "Timer", package: "Timer"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "NEHelper",
            dependencies: [
                "ExtensionIPC",
                "VPNShared",
                .product(name: "Timer", package: "Timer"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
            ]
        ),
        .target(
            name: "VPNAppCore",
            dependencies: [
                "Domain",
                "NetShield",
                "VPNShared",
                "VPNCrypto",
                "Strings",
                "Localization",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"), // AuthCredential
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "VPNCrypto",
            dependencies: [
                "Ergonomics",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "VPNSharedTesting",
            dependencies: [
                "Domain",
                "VPNShared",
                "VPNAppCore",
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
            ]
        ),
        .testTarget(
            name: "VPNAppCoreTests",
            dependencies: [
                "VPNAppCore",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(name: "VPNSharedTests", dependencies: ["VPNShared"]),
        .testTarget(
            name: "NEHelperTests",
            dependencies: [
                "NEHelper",
                "VPNSharedTesting",
                .product(name: "TimerMock", package: "Timer"),
            ]
        ),
        .testTarget(name: "VPNCryptoTests", dependencies: ["VPNCrypto"]),
    ]
)
