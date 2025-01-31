// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]),
        .library(
            name: "ModalsServices",
            targets: ["ModalsServices"]),
        .library(
            name: "Modals-macOS",
            targets: ["Modals-macOS"]),
        .library(
            name: "Modals-iOS",
            targets: ["Modals-iOS"])
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(name: "Overture", url: "https://github.com/pointfreeco/swift-overture", .exact("0.5.0")),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../SharedViews")
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: [
                "Overture",
                "Strings",
                "Theme"
            ],
            resources: [
                .process("Resources/Media.xcassets")
            ]
        ),
        .target(
            name: "ModalsServices",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: ["Modals", "Theme", "Ergonomics", "SharedViews"],
            resources: [
                .process("Resources")
            ]
        ),
        .target(
            name: "Modals-macOS",
            dependencies: ["Modals", "Theme", "Ergonomics", "SharedViews"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: ["Modals", "Overture", "Theme"]
        )
    ]
)
