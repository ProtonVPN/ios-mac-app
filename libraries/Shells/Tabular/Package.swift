// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tabular",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Tabular",
            targets: ["Tabular"]
        ),
    ],
    dependencies: [
        .package(path: "../../Features/Home"),
        .package(path: "../../Features/Modals"),
        .package(path: "../../Features/Payments"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Theme"),

        .package(path: "../../Core/NEHelper"),

        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Persistence"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
    ],
    targets: [
        .target(
            name: "Tabular",
            dependencies: [
                "Home",
                .product(name: "HomeShared", package: "Home"),
                .product(name: "Connection", package: "Connection"),
                "Domain",
                .product(name: "ModalsShared", package: "Modals"),
                .product(name: "Payments", package: "Payments"),
                .product(name: "PaymentsShared", package: "Payments"),
                "Strings",
                "Theme",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "TabularTests",
            dependencies: [
                "Tabular",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
        .testTarget(
            name: "TabularFastSnapshotTests",
            dependencies: [
                "Tabular",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
    ]
)
