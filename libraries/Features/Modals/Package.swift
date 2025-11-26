// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]
        ),
        .library(
            name: "ModalsServices",
            targets: ["ModalsServices"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),

        .package(path: "../../Core/SharedViews"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-overture", exact: "0.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),

    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: [
                .target(name: "Modals-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Modals-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ModalsShared",
            dependencies: [
                "Strings",
                "Theme",
                .product(name: "Overture", package: "swift-overture"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
            ],
            resources: [
                .process("Resources/Media.xcassets"),
            ]
        ),
        .target(
            name: "ModalsServices",
            dependencies: [
                "Domain",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: ["ModalsShared", "ModalsServices", "SharedViews"],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Modals-macOS",
            dependencies: ["ModalsShared", "ModalsServices", "SharedViews", "Ergonomics"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: [
                "ModalsShared",
                "ModalsServices",
            ]
        ),
    ]
)
