// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    defaultLocalization: "en",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Theme"),

        .package(url: "https://github.com/pointfreeco/swift-overture", exact: "0.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                "Theme",
                "Strings",
                .product(name: "Overture", package: "swift-overture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            resources: [.process("Assets.xcassets")]
        ),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
    ]
)
