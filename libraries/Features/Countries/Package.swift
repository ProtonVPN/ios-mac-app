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
        .package(path: "../../../external/protoncore"),

        .package(path: "../Modals"),
        .package(path: "../Search"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/LegacyCommon"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/Localization"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/Alamofire/AlamofireImage", exact: "4.2.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.15.8"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Countries",
            dependencies: [
                "LegacyCommon",
                "Theme",
                "CommonNetworking",
                "Domain",
                "Strings",
                "Modals",
                "Persistence",
                "Search",
                "Localization",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),

                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "AlamofireImage", package: "AlamofireImage"),
                .product(name: "SDWebImage", package: "SDWebImage"),
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
