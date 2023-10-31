// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NEHelper",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "NEHelper", targets: ["NEHelper"]),
        .library(name: "VPNAppCore", targets: ["VPNAppCore"]),
        .library(name: "VPNShared", targets: ["VPNShared"]),
        .library(name: "VPNCrypto", targets: ["VPNCrypto"]),
        .library(name: "VPNSharedTesting", targets: ["VPNSharedTesting"]),
    ],
    dependencies: [
        .package(path: "../../external/protoncore"),
        .package(path: "../Ergonomics"),
        .package(path: "../Timer"),
        .package(path: "../PMLogger"),
        .package(path: "../LocalFeatureFlags"),
        .package(path: "../Strings"),
        .package(url: "https://github.com/apple/swift-log.git", exact: "1.4.4"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "3.2.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies.git", exact: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", exact: "1.0.0"),
    ],
    targets: [
        .target(
            name: "VPNShared",
            dependencies: [
                "VPNCrypto",
                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "Timer", package: "Timer"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "PMLogger", package: "PMLogger"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "LocalFeatureFlags", package: "LocalFeatureFlags"),
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "NEHelper",
            dependencies: [
                .product(name: "Timer", package: "Timer"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "LocalFeatureFlags", package: "LocalFeatureFlags"),
                .core(module: "Utilities"),
                "VPNShared"
            ]
        ),
        .target(
            name: "VPNAppCore",
            dependencies: [
                "VPNShared",
                "VPNCrypto",
                "Strings",
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay")
            ]
        ),
        .target(
            name: "VPNCrypto",
            dependencies: [
                .product(name: "Dependencies", package: "swift-dependencies")
            ]
        ),
        .target(
            name: "VPNSharedTesting",
            dependencies: ["VPNShared", .product(name: "TimerMock", package: "Timer")]
        ),
        .testTarget(name: "VPNSharedTests", dependencies: ["VPNShared"]),
        .testTarget(name: "NEHelperTests", dependencies: ["NEHelper", "VPNSharedTesting"]),
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
