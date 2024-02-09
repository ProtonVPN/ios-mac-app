// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Domain",
            targets: ["Domain"]
        ),
    ],
    dependencies: [
        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),
        .package(path: "../../../external/protoncore") // Heavy dependency - logic that requires ProtonCore could live as extensions in another package
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Domain",
            dependencies: [
                "Strings",
                "Ergonomics",
                .product(name: "ProtonCoreUtilities", package: "protoncore"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
            ]
        )
    ]
)
