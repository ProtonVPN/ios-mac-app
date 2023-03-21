// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Onboarding",
    defaultLocalization: "en",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "Onboarding",
            targets: ["Onboarding"])
    ],
    dependencies: [
        .package(name: "Overture",
                 url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0")),
        .package(path: "../Modals"),
        .package(path: "../Theme")
    ],
    targets: [
        .target(
            name: "Onboarding",
            dependencies: ["Overture",
                            .product(name: "Modals-iOS", package: "Modals"),
                           "Theme"],
            resources: [
                .process("Storyboard.storyboard"),
                .process("Views/TourStepView.xib"),
                .process("Resources")
            ])
    ]
)
