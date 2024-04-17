// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PMLogger",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v17)
    ],
    products: [
        .library(
            name: "PMLogger",
            targets: ["PMLogger"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4")
    ],
    targets: [
        .target(
            name: "PMLogger",
            dependencies: [
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "PMLoggerTests",
            dependencies: ["PMLogger"]),
    ]
)
