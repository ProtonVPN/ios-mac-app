// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetShield",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "NetShield",
            targets: ["NetShield"]),
        .library(
            name: "NetShield-macOS",
            targets: ["NetShield-macOS"]),
        .library(
            name: "NetShield-iOS",
            targets: ["NetShield-iOS"])
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
                "Strings",
                "Theme"
            ]
        ),
        .target(
            name: "NetShield-iOS",
            dependencies: ["NetShield", "Theme", "Ergonomics"]
        ),
        .target(
            name: "NetShield-macOS",
            dependencies: ["NetShield", "Theme", "Ergonomics"]
        ),
        .testTarget(
            name: "NetShieldTests",
            dependencies: ["NetShield", "Theme"]
        )
    ]
)
