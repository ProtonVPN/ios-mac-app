// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15)],
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
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0"))
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: ["Overture"],
            resources: [
                .process("Resources/Media.xcassets")
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: ["Modals"],
            resources: []
        ),
        .target(
            name: "Modals-macOS",
            dependencies: ["Modals"],
            resources: []
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: ["Modals", "Overture"]
            )
    ]
)
