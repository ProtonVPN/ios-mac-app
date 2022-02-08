// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [.iOS("12.1")],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]),
    ],
    dependencies: [
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0"))
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: ["Overture"],
            resources: [
                .process("UpsellViewController.storyboard")
            ]),
        .testTarget(
            name: "ModalsTests",
            dependencies: ["Modals"])
    ]
)
