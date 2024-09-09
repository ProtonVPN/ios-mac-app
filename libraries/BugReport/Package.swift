// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
    products: [
        .library(
            name: "BugReport",
            targets: ["BugReport"]),
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.13.1")),
        .package(url: "https://github.com/pointfreeco/swift-navigation", from: "2.2.0"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.3.4"),
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftNavigation", package: "swift-navigation"),
                .product(name: "Perception", package: "swift-perception"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BugReportTests",
            dependencies: ["BugReport"],
            resources: [
                .process("example1.json"),
            ]),
    ]
)
