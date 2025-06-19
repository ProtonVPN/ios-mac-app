// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "tvOS",
    defaultLocalization: "en",
    platforms: [
        .tvOS(.v17),
    ],
    products: [
        .library(name: "tvOS", targets: ["tvOS"]),
        .library(name: "tvOSTestSupport", targets: ["tvOSTestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.18.0")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.17.6")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.2")),
        .package(path: "../../external/protoncore"),
        .package(path: "../Shared/CommonNetworking"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Domain"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../NEHelper"),
        .package(path: "../Modals"),
    ],
    targets: [
        .target(
            name: "tvOS",
            dependencies: [
                "Ergonomics",
                "Theme",
                "CommonNetworking",
                "Connection",
                "Persistence",
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "VPNShared", package: "NEHelper"), // AuthKeychain
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Domain", package: "Domain"),
                .core(module: "ForceUpgrade"),
                .core(module: "Networking"),
                .core(module: "PaymentsV2"),
                .core(module: "UIFoundations"),
                .core(module: "Services"),
            ],
            resources: [
                .process("Resources/Assets.xcassets"),
            ]
        ),
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
            ]
        ),
        .testTarget(
            name: "tvOSSnapshotTests",
            dependencies: [
                "tvOS",
                "tvOSTestSupport",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "ConnectionTestSupport", package: "Connection"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ]
        ),
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
