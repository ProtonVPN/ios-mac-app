// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectWidget",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "ConnectWidget",
            targets: ["ConnectWidget"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.17.1")),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Strings"),
        .package(path: "../NEHelper"),
        .package(path: "../SharedViews"),
        ],
    targets: [
        .target(
            name: "ConnectWidget",
            dependencies: [
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                "Theme",
                "Strings",
                "SharedViews",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
            ],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "ConnectWidgetTests",
            dependencies: ["ConnectWidget"]
        ),
    ]
)
