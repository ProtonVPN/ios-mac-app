// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Review",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Review",
            targets: ["Review"]
        ),
    ],
    dependencies: [.package(path: "../../Foundations/Domain")],
    targets: [
        .target(
            name: "Review",
            dependencies: []
        ),
        .testTarget(
            name: "ReviewTests",
            dependencies: [
                "Review",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
    ]
)
