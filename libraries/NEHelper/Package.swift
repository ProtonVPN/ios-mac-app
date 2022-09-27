// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NEHelper",
    platforms: [
        .iOS(.v14),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "NEHelper",
            targets: ["NEHelper"]),
        .library(
            name: "VPNShared",
            targets: ["VPNShared"]),
    ],
    dependencies: [
        .package(path: "../Timer"),
        .package(path: "../PMLogger"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "3.2.1"),
    ],
    targets: [
        .target(
            name: "VPNShared",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .target(
            name: "NEHelper",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                "VPNShared",
            ]
        ),
        .testTarget(
            name: "NEHelperTests",
            dependencies: ["NEHelper"]),
    ]
)
