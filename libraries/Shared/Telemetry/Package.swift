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
        .package(url: "https://github.com/almazrafi/DictionaryCoder", .upToNextMajor(from: "1.1.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.5.2")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/ashleymills/Reachability.swift", .upToNextMajor(from: "5.1.0")),
        .package(path: "../Connection"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Core/NEHelper"),
        .package(path: "../ConnectionInventory"),
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
                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreTelemetry", package: "protoncore"),
            ]
        ),
        .testTarget(
            name: "TelemetryTests",
            dependencies: ["Telemetry"]
        ),
    ]
)
