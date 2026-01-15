// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Countries",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Countries",
            targets: ["Countries"]
        ),
    ],
    dependencies: [
        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/LegacyCommon"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/CommonNetworking"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Countries",
            dependencies: [
                "Domain",
                "Strings",
                "CommonNetworking",
                "Persistence",
                "Localization",
                "LegacyCommon",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "CountriesTests",
            dependencies: [
                "Countries",
            ]
        ),
    ]
)
