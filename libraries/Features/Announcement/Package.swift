// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Announcement",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Announcement",
            targets: ["Announcement"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../NEHelper"),
        .package(path: "../../LegacyCommon"),
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.15.8"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        .target(
            name: "Announcement",
            dependencies: [
                "Strings",
                "Ergonomics",
                "Domain",
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
                .product(name: "SDWebImage", package: "SDWebImage"),
            ]
        ),
        .testTarget(
            name: "AnnouncementTests",
            dependencies: [
                "Announcement",
                "LegacyCommon",
                "Domain",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
            ]
        ),
    ]
)
