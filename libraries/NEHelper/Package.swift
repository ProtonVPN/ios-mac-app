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
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "NEHelper",
            targets: ["NEHelper"]),
    ],
    dependencies: [
        .package(path: "../Timer"),
        .package(path: "../PMLogger"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "3.2.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "NEHelper",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
            ]
        ),
        .testTarget(
            name: "NEHelperTests",
            dependencies: ["NEHelper"]),
    ]
)
