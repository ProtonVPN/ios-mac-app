// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PCAP",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "PCAP",
            targets: ["PCAP"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Localization"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
    ],
    targets: [
        .target(
            name: "PCAP",
            dependencies: [
                .target(name: "PCAP-iOS", condition: .when(platforms: [.iOS])),
            ]
        ),
        .target(
            name: "PCAPShared",
            dependencies: [
                "Connection",
                "Theme",
                "Domain",
                "Localization",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .target(
            name: "PCAP-iOS",
            dependencies: [
                "PCAPShared",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PCAPTests",
            dependencies: [
                "PCAP",
                "PCAPShared",
                .target(name: "PCAP-iOS", condition: .when(platforms: [.iOS])),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
