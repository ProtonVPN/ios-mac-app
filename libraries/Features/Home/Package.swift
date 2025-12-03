// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Home",
            targets: ["Home"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Modals"),
        .package(path: "../NetShield"),
        .package(path: "../ConnectionDetails"),
        .package(path: "../Announcement"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/ConnectionInventory"),

        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
        .package(url: "https://github.com/airbnb/lottie-ios", .upToNextMajor(from: "4.0.0")),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                .target(name: "Home-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Home-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "HomeShared",
            dependencies: [
                "CommonNetworking",
                "Connection",
                "Localization",
                "Persistence",
                "Theme",
                "SharedViews",
                "NetShield",
                "Ergonomics",
                "Announcement",
                "ConnectionInventory",
                "ConnectionDetails",
                "Domain",
                "PMLogger",
                .product(name: "Modals", package: "Modals"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "LocalAgent", package: "Connection"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),

                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            exclude: ["swiftgen.yml"],
            resources: [
                .process("Resources/BlankMap-World.svg"),
                .process("Resources/widget-ios-v4.json"),
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "HomeShared",
            ]
        ),
        .target(
            name: "Home-macOS",
            dependencies: [
                "HomeShared",
            ],
            resources: []
        ),
        .target(
            name: "SnapshotTestsSupport",
            dependencies: [
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: [
                "HomeShared",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "HomeFastSnapshotTests",
            dependencies: [
                "Home",
                "SnapshotTestsSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "HomeSlowSnapshotTests",
            dependencies: [
                "Home",
                "SnapshotTestsSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
    ]
)
