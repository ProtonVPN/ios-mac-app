// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WireGuardExtension",
    platforms: [
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "WireGuardExtension",
            targets: ["WireGuardExtension"]
        ),
        .library(
            name: "WireGuardLogging",
            targets: ["WireGuardLogging"]
        ),
        .library(
            name: "WireGuardLoggingC",
            targets: ["WireGuardLoggingC"]
        ),
    ],
    dependencies: [
        .package(name: "WireGuardKit", path: "../../external/wireguard-apple")
    ],
    targets: [
        .target(
            name: "WireGuardExtension",
            dependencies: ["WireGuardKit", "WireGuardLogging"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WireGuardLogging",
            dependencies: ["WireGuardLoggingC"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .target(
            name: "WireGuardLoggingC",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "WireGuardExtensionTests",
            dependencies: ["WireGuardExtension"]
        ),
    ]
)
