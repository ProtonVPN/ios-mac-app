// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "BugReport",
            targets: ["BugReport"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Theme"),

        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/CommonNetworking"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.6.0")),
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [
                .target(name: "BugReport-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "BugReport-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "BugReportShared",
            dependencies: [
                "Strings",
                "PMLogger",
                "CommonNetworking",
                "Ergonomics",
                "Theme",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftNavigation", package: "swift-navigation"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "BugReport-iOS",
            dependencies: [
                "BugReportShared",
            ]
        ),
        .target(
            name: "BugReport-macOS",
            dependencies: [
                "BugReportShared",
                "SharedViews",
            ],
            resources: []
        ),
        .testTarget(
            name: "BugReportTests",
            dependencies: ["BugReportShared"],
            resources: [
                .process("example1.json"),
            ]
        ),
    ]
)
