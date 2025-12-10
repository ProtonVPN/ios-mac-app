// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VPNNetworking",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "VPNNetworking",
            targets: ["VPNNetworking"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Localization"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
    ],
    targets: [
        .target(
            name: "VPNNetworking",
            dependencies: [
                "Localization",
                "Domain",
                "PMLogger",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),

                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .testTarget(
            name: "VPNNetworkingTests",
            dependencies: ["VPNNetworking"]
        ),
    ]
)
