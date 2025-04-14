// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Home",
            targets: ["Home"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
        .package(url: "https://github.com/airbnb/lottie-ios", .upToNextMajor(from: "4.0.0")),
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../Foundations/Domain"),
        .package(path: "../Shared/CommonNetworking"),
        .package(path: "../NEHelper"),
        .package(path: "../SharedViews"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Shared/ConnectionInventory"),
        .package(path: "../Modals"),
        .package(path: "../NetShield"),
        .package(path: "../ConnectionDetails"),
        .package(path: "../Announcement"),
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
                "Persistence",
                "Theme",
                "SharedViews",
                "NetShield",
                "Ergonomics",
                "Announcement",
                "ConnectionInventory",
                "ConnectionDetails",
                .product(name: "Lottie", package: "lottie-ios"),
                .product(name: "Modals", package: "Modals"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
            ],
            exclude: ["swiftgen.yml"],
            resources: [
                .process("Resources/BlankMap-World.svg"),
                .process("Resources/widget-ios-v4.json"),
                .process("Resources/Assets.xcassets")
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
                "HomeShared"
            ],
            resources: []
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: [
                "HomeShared",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ]
        ),
        .testTarget(
            name: "HomeiOSTests",
            dependencies: [
                "Home",
                "Home-iOS",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture")
            ]
        ),
        .testTarget(
            name: "HomeSnapshotTests",
            dependencies: [
                "Home",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        )
    ]
)
