// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Settings",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [.library(name: "Settings", targets: ["Settings"])],
    dependencies: [
        .package(path: "../Theme"),
        .package(path: "../Strings"),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "0.54.1"),
        .package(url: "https://github.com/pointfreeco/swiftui-navigation", from: "0.8.0")
    ],
    targets: [
        .target(
            name: "Settings",
            dependencies: [
                "Theme",
                "Strings",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SwiftUINavigation", package: "swiftui-navigation")
            ]
        ),
        .testTarget(name: "SettingsTests", dependencies: ["Settings"])
    ]
)
