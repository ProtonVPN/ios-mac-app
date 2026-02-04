// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Telemetry",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Telemetry",
            targets: ["Telemetry"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Connection"),
        .package(path: "../ConnectionInventory"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/almazrafi/DictionaryCoder", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.5.2")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),

    ],
    targets: [
        .target(
            name: "Telemetry",
            dependencies: [
                "Ergonomics",
                "Domain",
                "Connection",
                "ConnectionInventory",
                .product(name: "DictionaryCoder", package: "DictionaryCoder"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCorePaymentsV2", package: "protoncore"),
                .product(name: "ProtonCoreTelemetry", package: "protoncore"),
            ]
        ),
        .testTarget(
            name: "TelemetryTests",
            dependencies: [
                "Telemetry",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
