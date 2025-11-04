// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Domain",
    platforms: [
        .iOS(.v17),
        .tvOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "DomainTestSupport", targets: ["DomainTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"), // Heavy dependency - logic that requires ProtonCore could live as extensions in another package

        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.7.0")),
    ],
    targets: [
        .executableTarget(name: "errordecoder", path: "Sources/ErrorDecoder"),
        .target(
            name: "Domain",
            dependencies: [
                "Strings",
                "Ergonomics",
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
            ],
            resources: [.process("Resources")]
        ),
        .target(name: "DomainTestSupport", dependencies: ["Domain"]),
        .testTarget(
            name: "DomainTests",
            dependencies: ["Domain"]
        ),
    ]
)
