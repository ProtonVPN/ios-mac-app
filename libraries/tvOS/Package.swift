// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tvOS",
    defaultLocalization: "en",
    platforms: [
        .tvOS(.v17)
    ],
    products: [
        .library(name: "tvOS", targets: ["tvOS"]),
        .library(name: "tvOSTestSupport", targets: ["tvOSTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.10.2"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", exact: "1.16.0"),
        .package(path: "../../external/protoncore"),
        .package(path: "../Shared/CommonNetworking"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/PMLogger"),
        .package(path: "../Foundations/Domain"),
        .package(path: "../Core/NEHelper"),
    ],
    targets: [
        .target(
            name: "tvOS",
            dependencies: [
                "Theme",
                "CommonNetworking",
                "Connection",
                "Persistence",
                .product(name: "VPNShared", package: "NEHelper"), // AuthKeychain
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .core(module: "ForceUpgrade"),
                .core(module: "Networking"),
                .core(module: "UIFoundations"),
                .core(module: "Services")
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]),
        .target(
            name: "tvOSTestSupport",
            dependencies: ["tvOS"]
        ),
        .testTarget(
            name: "tvOSTests",
            dependencies: [
                "tvOS",
                "tvOSTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ConnectionTestSupport", package: "Connection"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
