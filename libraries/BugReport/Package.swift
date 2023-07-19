// swift-tools-version: 5.7
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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "0.55.0"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", exact: "0.8.0"),
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation")
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
