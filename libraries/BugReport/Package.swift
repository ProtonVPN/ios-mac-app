// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "BugReport",
            targets: ["BugReport"]
        ),
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/PMLogger"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.3.0")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-identified-collections", .upToNextMajor(from: "1.1.1")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.6.1")),
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [
                "Strings",
                "PMLogger",
                .product(name: "Logging", package: "swift-log"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "BugReportTests",
            dependencies: [
                "BugReport",
                "PMLogger",
            ],
            resources: [
                .process("example1.json"),
            ]
        ),
    ]
)
