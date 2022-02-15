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
            targets: ["Modals"])
    ],
    dependencies: [
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0"))
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: ["Overture"],
            resources: [
                .process("Views/FeatureView.xib"),
                .process("ViewControllers/UpsellViewController.storyboard"),
                .process("Resources/Media.xcassets")
            ]
        )
    ]
)
