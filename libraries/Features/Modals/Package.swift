// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]
        ),
        .library(
            name: "ModalsServices",
            targets: ["ModalsServices"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),

        .package(path: "../../Core/SharedViews"),
        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-overture", exact: "0.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: [
                "ModalsShared",
                .target(name: "Modals-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Modals-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ModalsShared",
            dependencies: [
                "Domain",
                "Strings",
                "Theme",
                "SharedViews",
                .product(name: "VPNAppCore", package: "NEHelper"),

                .product(name: "Overture", package: "swift-overture"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [
                .process("Resources/Media.xcassets"),
            ]
        ),
        .target(
            name: "ModalsServices",
            dependencies: [
                "Domain",
                "Strings",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: [
                "ModalsShared",
                .product(name: "VPNShared", package: "NEHelper"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Modals-macOS",
            dependencies: [
                "ModalsShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: [
                "ModalsShared",
                .target(name: "Modals-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Modals-macOS", condition: .when(platforms: [.macOS])),

                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
    ]
)
