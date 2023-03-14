// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NEHelper",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "NEHelper", targets: ["NEHelper"]),
        .library(name: "VPNShared", targets: ["VPNShared"]),
        .library(name: "VPNSharedTesting", targets: ["VPNSharedTesting"]),
    ],
    dependencies: [
        .package(path: "../Timer"),
        .package(path: "../PMLogger"),
        .package(path: "../LocalFeatureFlags"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "3.2.1"),
    ],
    targets: [
        .target(
            name: "VPNShared",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "LocalFeatureFlags", package: "LocalFeatureFlags"),
            ]
        ),
        .testTarget(
            name: "VPNSharedTests",
            dependencies: ["VPNShared"]
        ),
        
        .target(
            name: "VPNSharedTesting",
            dependencies: ["VPNShared", .product(name: "TimerMock", package: "Timer")]
        ),
        
        .target(
            name: "NEHelper",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                .product(name: "LocalFeatureFlags", package: "LocalFeatureFlags"),
                "VPNShared",
            ]
        ),
        .testTarget(
            name: "NEHelperTests",
            dependencies: ["NEHelper", "VPNSharedTesting"]
        ),
    ]
)
