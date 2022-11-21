// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalFeatureFlags",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LocalFeatureFlags",
            targets: ["LocalFeatureFlags"]),
        .plugin(name: "EmbedPlistData", targets: ["EmbedPlistData"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LocalFeatureFlags",
            plugins: [.plugin(name: "EmbedPlistData")]),
        .testTarget(
            name: "LocalFeatureFlagsTests",
            dependencies: ["LocalFeatureFlags"]),
        .plugin(name: "FeatureFlagger", capability: .command(intent: .custom(verb: "ff",
                                                                             description: "Toggle feature flags in plist entries."),
                                                             permissions: [.writeToPackageDirectory(reason: "To modify the feature flags plist file.")])),
        .plugin(name: "EmbedPlistData", capability: .buildTool())
    ]
)
