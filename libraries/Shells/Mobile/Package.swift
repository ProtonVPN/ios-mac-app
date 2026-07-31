// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mobile",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Mobile",
            targets: ["Mobile"]
        ),
    ],
    dependencies: [
        .package(path: "../../Features/Home"),

        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),

        .package(path: "../../Core/NEHelper"),

        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
    ],
    targets: [
        .target(
            name: "Mobile",
            dependencies: [
                "Home",
                .product(name: "HomeShared", package: "Home"),
                "Domain",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "MobileTests",
            dependencies: [
                "Mobile",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
    ]
)
