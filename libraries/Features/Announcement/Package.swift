// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Announcement",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Announcement",
            targets: ["Announcement"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Timer"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/LegacyCommon"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Connection"),

        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.15.8"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
    ],
    targets: [
        .target(
            name: "Announcement",
            dependencies: [
                "Strings",
                "Ergonomics",
                "Domain",
                "Timer",
                "CommonNetworking",
                "LegacyCommon",
                "Connection",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "SDWebImage", package: "SDWebImage"),
            ]
        ),
        .testTarget(
            name: "AnnouncementTests",
            dependencies: [
                "Announcement",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
    ]
)
