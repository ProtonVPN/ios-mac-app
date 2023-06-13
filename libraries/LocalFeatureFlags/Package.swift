// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalFeatureFlags",
    products: [
        .library(
            name: "LocalFeatureFlags",
            targets: ["LocalFeatureFlags"]),
    ],
    dependencies: [
        .package(url: "https://github.com/protonjohn/plistutil", exact: "0.0.2")
    ],
    targets: [
        .target(
            name: "LocalFeatureFlags",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LocalFeatureFlagsTests",
            dependencies: ["LocalFeatureFlags"],
            resources: [
                .copy("Resources")
            ]
        ),
        .plugin(
            name: "FeatureFlagger",
            capability: .command(
                intent: .custom(
                    verb: "ff",
                    description: "Toggle feature flags in plist entries."),
                permissions: [
                    .writeToPackageDirectory(
                        reason: "To modify the feature flags plist file."
                    )
                ]
            ),
            dependencies: [
                .product(name: "plistutil", package: "PlistUtil")
            ]
        ),
    ]
)
