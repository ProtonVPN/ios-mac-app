// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "SharedViews",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SharedViews",
            targets: ["SharedViews"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../NEHelper"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../../external/protoncore"),

        .package(path: "../../Shared/Localization"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        .target(
            name: "SharedViews",
            dependencies: [
                "Theme",
                "Ergonomics",
                "Strings",
                "Localization",
                "Domain",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
    ]
)
