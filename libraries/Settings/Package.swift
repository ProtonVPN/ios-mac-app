// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "Settings", targets: ["Settings"])],
    dependencies: [
        .package(path: "../Theme"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.54.1")
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                "Theme",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(name: "SettingsTests", dependencies: ["Settings"])
    ]
)
