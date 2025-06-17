// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetShield",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .tvOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "NetShield",
            targets: ["NetShield"]
        ),
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
    ],
    targets: [
        .target(
            name: "NetShield",
            dependencies: [
                .target(name: "NetShield-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "NetShield-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "NetShieldShared",
            dependencies: ["Strings", "Theme", "Ergonomics"]
        ),
        .target(
            name: "NetShield-iOS",
            dependencies: ["NetShieldShared"]
        ),
        .target(
            name: "NetShield-macOS",
            dependencies: ["NetShieldShared"]
        ),
        .testTarget(
            name: "NetShieldTests",
            dependencies: ["NetShield"]
        ),
    ]
)
