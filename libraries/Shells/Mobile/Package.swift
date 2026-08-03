// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mobile",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Mobile",
            targets: ["Mobile"]
        ),
    ],
    dependencies: [
        .package(path: "../../Features/Home"),
        .package(path: "../../Features/Payments"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Theme"),

        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/Persistence"),

        .package(path: "../../../external/protoncore"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
    ],
    targets: [
        .target(
            name: "Mobile",
            dependencies: [
                "Home",
                .product(name: "HomeShared", package: "Home"),
                "Domain",
                .product(name: "Payments", package: "Payments"),
                .product(name: "PaymentsShared", package: "Payments"),
                "Strings",
                "Theme",
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "MobileTests",
            dependencies: [
                "Mobile",
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
        .testTarget(
            name: "MobileFastSnapshotTests",
            dependencies: [
                "Mobile",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
    ]
)
