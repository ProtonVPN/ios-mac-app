// swift-tools-version:5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Modals",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "Modals",
            targets: ["Modals"]
        ),
        .library(
            name: "ModalsServices",
            targets: ["ModalsServices"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-overture", exact: "0.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../Foundations/Domain"),
        .package(path: "../SharedViews"),
        .package(path: "../../external/protoncore"),
    ],
    targets: [
        .target(
            name: "Modals",
            dependencies: [
                .target(name: "Modals-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Modals-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "ModalsShared",
            dependencies: [
                "Strings",
                "Theme",
                .core(module: "UIFoundations"),
                .product(name: "Overture", package: "swift-overture"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
            ],
            resources: [
                .process("Resources/Media.xcassets"),
            ]
        ),
        .target(
            name: "ModalsServices",
            dependencies: [
                "Domain",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .target(
            name: "Modals-iOS",
            dependencies: ["ModalsShared", "ModalsServices", "SharedViews"],
            resources: [
                .process("Resources"),
            ]
        ),
        .target(
            name: "Modals-macOS",
            dependencies: ["ModalsShared", "ModalsServices", "SharedViews", "Ergonomics"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "ModalsTests",
            dependencies: [
                "ModalsShared",
                "ModalsServices",
            ]
        ),
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
