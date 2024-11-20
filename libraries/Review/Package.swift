// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Review",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(
            name: "Review",
            targets: ["Review"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Review",
            dependencies: []),
        .testTarget(
            name: "ReviewTests",
            dependencies: ["Review"]),
    ]
)
