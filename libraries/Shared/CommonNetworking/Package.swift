// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonNetworking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "CommonNetworking", targets: ["CommonNetworking"]),
        .library(name: "CommonNetworkingTestSupport", targets: ["CommonNetworkingTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Localization"),
        .package(path: "../Persistence"),

        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/ProtonMail/TrustKit", revision: "d107d7cc825f38ae2d6dc7c54af71d58145c3506"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
    ],
    targets: [
        .target(
            name: "CommonNetworking",
            dependencies: [
                "PMLogger",
                "Domain",
                "Ergonomics",
                "Localization",
                "Persistence",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"), // UnauthKeychain
                .product(name: "VPNShared", package: "NEHelper"), // AuthKeychain

                // Core/Accounts
                .product(name: "ProtonCoreAPIClient", package: "protoncore"),
                .product(name: "ProtonCoreAuthentication", package: "protoncore"),
                .product(name: "ProtonCoreDataModel", package: "protoncore"),
                .product(name: "ProtonCoreDoh", package: "protoncore"),
                .product(name: "ProtonCoreEnvironment", package: "protoncore"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreFoundations", package: "protoncore"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCoreServices", package: "protoncore"),
                .product(name: "ProtonCoreUtilities", package: "protoncore"),

                // External
                .product(name: "TrustKit", package: "TrustKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            swiftSettings: [
                .define("TLS_PIN_DISABLE", .when(configuration: .debug)),
            ]
        ),
        .target(
            name: "CommonNetworkingTestSupport",
            dependencies: [
                "CommonNetworking",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(name: "CommonNetworkingTests", dependencies: ["CommonNetworking"]),
    ]
)
