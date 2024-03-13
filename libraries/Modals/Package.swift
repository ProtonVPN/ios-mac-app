// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]),
        .library(
            name: "Modals-macOS",
            targets: ["Modals-macOS"]),
        .library(
            name: "Modals-iOS",
            targets: ["Modals-iOS"])
    ],
    dependencies: [
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Strings"),
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0")),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../SharedViews")
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: [
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                "Overture",
                "Strings",
                "Theme"
            ],
            resources: [
                .process("Resources/Media.xcassets")
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: ["Modals", "Theme", "Ergonomics", "SharedViews"],
            resources: [.process("Resources")]
        ),
        .target(
            name: "Modals-macOS",
            dependencies: ["Modals", "Theme", "Ergonomics", "SharedViews"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: ["Modals", "Overture", "Theme"]
        )
    ]
)
