// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedViews",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
    products: [
        .library(
            name: "SharedViews",
            targets: ["SharedViews"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../Theme"),
        .package(path: "../NEHelper"),
        .package(path: "../Strings"),
        
        // 3rd party
        .package(
          url: "https://github.com/pointfreeco/swift-dependencies.git",
          from: "0.5.1"
        ),
    ],
    targets: [
        .target(
            name: "SharedViews",
            dependencies: [
                "Theme",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]),
        .testTarget(
            name: "SharedViewsTests",
            dependencies: ["SharedViews"]
        ),
    ]
)
