// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ConnectionDetails",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],

    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ConnectionDetails",
            targets: ["ConnectionDetails"]),

        .library(
            name: "ConnectionDetails-iOS",
            targets: ["ConnectionDetails-iOS"]),
        .library(
            name: "ConnectionDetails-macOS",
            targets: ["ConnectionDetails-macOS"]),
    ],
    dependencies: [
        .package(path: "../Theme"),
        .package(path: "../Strings"),
        .package(path: "../NEHelper"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture",
                 branch: "prerelease/1.0"),
    ],
    targets: [
        .target(
            name: "ConnectionDetails",
            dependencies: [
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "ConnectionDetails-iOS",
            dependencies: [
                "Strings",
                "ConnectionDetails",
                .product(name: "Theme-iOS", package: "Theme"),
                .product(name: "VPNShared", package: "NEHelper"),
                // 3rd party
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ],
            resources: []
        ),
        .target(
            name: "ConnectionDetails-macOS",
            dependencies: [
                "ConnectionDetails",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Theme-macOS", package: "Theme"),
            ],
            resources: []
        ),

        .testTarget(
            name: "ConnectionDetailsTests",
            dependencies: ["ConnectionDetails"]
        ),
    ]
)
