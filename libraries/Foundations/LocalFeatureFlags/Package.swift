// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LocalFeatureFlags",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "LocalFeatureFlags",
            targets: ["LocalFeatureFlags"]),
    ],
    dependencies: [
        .package(url: "https://github.com/protonjohn/plistutil", exact: "0.0.2"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4"),
        .package(path: "../PMLogger"),
    ],
    targets: [
        .target(
            name: "LocalFeatureFlags",
            dependencies: [
                "PMLogger",
                .product(name: "Logging", package: "swift-log")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LocalFeatureFlagsTests",
            dependencies: ["LocalFeatureFlags", "PMLogger"]
//            resources: [
//                .copy("LocalFeatureFlags/Resources")
//            ]
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
