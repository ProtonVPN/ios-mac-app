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
        .package(path: "../../../external/vpn-core-apple"),

        .package(path: "../Strings"),
        .package(path: "../Ergonomics"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.6.1")),
    ],
    targets: [
        .executableTarget(name: "errordecoder", path: "Sources/ErrorDecoder"),
        .target(
            name: "Domain",
            dependencies: [
                "Strings",
                "Ergonomics",
                .product(name: "VPNCoreTypes", package: "vpn-core-apple"),
                .product(name: "IPCErgonomics", package: "Ergonomics"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "DependenciesMacros", package: "swift-dependencies"),
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
