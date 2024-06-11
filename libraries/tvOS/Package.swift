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
        .package(path: "../../external/protoncore"),
        .package(path: "../Shared/CommonNetworking"),
        .package(path: "../Shared/Connection"),
        .package(path: "../Shared/Persistence"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/PMLogger"),
    ],
    targets: [
        .target(
            name: "tvOS",
            dependencies: [
                "Theme",
                "CommonNetworking",
                "Connection",
                "Persistence",
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
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]),
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
