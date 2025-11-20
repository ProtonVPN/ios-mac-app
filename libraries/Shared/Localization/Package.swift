// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Localization",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Localization",
            targets: ["Localization"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../../external/protoncore"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        .target(
            name: "Localization",
            dependencies: [
                "Domain",
                "Strings",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
            ],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LocalizationTests",
            dependencies: ["Localization"]
        ),
    ]
)
