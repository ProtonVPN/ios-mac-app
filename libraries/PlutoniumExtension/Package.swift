// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlutoniumExtension",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PlutoniumExtension",
            targets: ["PlutoniumExtension"]),
    ],
    dependencies: [
        .package(path: "../Foundations/PMLogger")
    ],
    targets: [
        .target(
            name: "PlutoniumExtension",
            dependencies: [
                "PMLogger"
            ]),
        .testTarget(
            name: "PlutoniumExtensionTests",
            dependencies: ["PlutoniumExtension"]
        ),
    ]
)

