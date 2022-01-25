// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboarding",
    defaultLocalization: "en",
    platforms: [.iOS("12.1")],
    products: [
        .library(
            name: "Onboarding",
            targets: ["Onboarding"])
    ],
    dependencies: [
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0"))
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: ["Overture"],
        resources: [
            .process("Storyboard.storyboard"),
            .process("Views/TourStepView.xib"),
            .process("Views/FeatureView.xib"),
            .process("Resources")
        ])
    ]
)
