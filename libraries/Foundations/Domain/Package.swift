// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "DomainTestSupport", targets: ["DomainTestSupport"]),
    ],
    dependencies: [
        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),
        .package(path: "../../../external/protoncore") // Heavy dependency - logic that requires ProtonCore could live as extensions in another package
    ],
    targets: [
        .target(
            name: "Domain",
            dependencies: [
                "Strings",
                "Ergonomics",
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
            ]
        ),
        .target(name: "DomainTestSupport", dependencies: ["Domain"]),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
    ]
)
