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
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.9.2"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", exact: "1.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-perception", exact: "1.1.4"),
    ],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation"),
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
