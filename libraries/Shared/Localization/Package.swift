// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Localization",
    platforms: [.iOS(.v15), .macOS(.v11)],
    products: [
        .library(
            name: "Localization",
            targets: ["Localization"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings")
    ],
    targets: [
        .target(
            name: "Localization",
            dependencies: ["Domain", "Strings"]
        ),
    ]
)
