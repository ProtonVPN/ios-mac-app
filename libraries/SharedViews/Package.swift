// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "SharedViews",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v11)],
    products: [
        .library(
            name: "SharedViews",
            targets: ["SharedViews"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../NEHelper"),
        .package(path: "../Shared/Localization"),

        // 3rd party
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.1"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.3.5"),
        .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    ],
    targets: [
        .target(
            name: "SharedViews",
            dependencies: [
                "SharedViewsMacros",
                "Theme",
                "Ergonomics",
                "Localization",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Perception", package: "swift-perception"),
            ]
        ),
        .macro(
            name: "SharedViewsMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
    ]
)
