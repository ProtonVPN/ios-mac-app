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
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: [],
        resources: [
            .process("Storyboard.storyboard"),
            .process("Views/TourStepView.xib"),
            .process("Resources")
        ])
    ]
)
