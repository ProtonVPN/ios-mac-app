// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WidgetReload",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "WidgetReload", targets: ["WidgetReload"]),
    ],
    dependencies: [
        // Only for `JSONAppStorageKey`, behind the DEBUG-only reload counter.
        .package(path: "../Domain"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-concurrency-extras", .upToNextMajor(from: "1.3.1")),
    ],
    targets: [
        .target(
            name: "WidgetReload",
            dependencies: [
                "Domain",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
            ]
        ),
        .testTarget(
            name: "WidgetReloadTests",
            dependencies: [
                "WidgetReload",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ConcurrencyExtras", package: "swift-concurrency-extras"),
            ]
        ),
    ]
)
