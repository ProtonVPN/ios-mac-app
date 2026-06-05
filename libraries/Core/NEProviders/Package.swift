// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum ProTUNFFITargetKind {
    // TODO: ProTUN: support uploads to S3 for public release
    static let current: Self = .remote(
        url: "https://nexus.protontech.ch/repository/vpn-protun/apple-protun-merged-debug/protunFFI-debug.xcframework.zip",
        checksum: "615d615efd39e05b92786c301d15b422a5580a9b57955e5a2cd8f76f9a6f9d16"
    )

    case local
    case remote(url: String, checksum: String)

    var target: PackageDescription.Target {
        switch self {
        case .local:
            .binaryTarget(name: "protunFFI", path: "Frameworks/protunFFI.xcframework")
        case let .remote(url, checksum):
            .binaryTarget(name: "protunFFI", url: url, checksum: checksum)
        }
    }
}

let swiftLintPluginEnabled: Bool = false
let protunExtensionPlugins: [PackageDescription.Target.PluginUsage] = swiftLintPluginEnabled ? [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")] : []

let package = Package(
    name: "WireGuardExtension",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
    ],
    products: [
        .library(
            name: "ProTUNExtension",
            targets: ["ProTUNExtension"]
        ),
        .library(
            name: "WireGuardExtension",
            targets: ["WireGuardExtension"]
        ),
        .library(
            name: "WireGuardLogging",
            targets: ["WireGuardLogging"]
        ),
        .library(
            name: "WireGuardLoggingC",
            targets: ["WireGuardLoggingC"]
        ),
    ],
    dependencies: [
        .package(name: "WireGuardKit", path: "../../../external/wireguard-apple"),
        .package(name: "vpn-core-apple", path: "../../../external/vpn-core-apple"),

        .package(path: "../NEHelper"),

        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Connection"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.2"),
    ],
    targets: [
        .target(
            name: "ProTUNExtension",
            dependencies: [
                "Domain",
                "NEHelper",
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ConnectionShared", package: "Connection"),
                .product(name: "VPNCoreTypes", package: "vpn-core-apple"),
                .product(name: "VPNCoreExtension", package: "vpn-core-apple"),
                .product(name: "LocalAgent", package: "Connection"),
                .product(name: "LocalAgentIPC", package: "Connection"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .target(name: "protunFFI", condition: .when(platforms: [.iOS, .macOS])),
            ],
            plugins: protunExtensionPlugins
        ),
        .target(
            name: "WireGuardLoggingC",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .target(
            name: "WireGuardLogging",
            dependencies: [
                "WireGuardLoggingC",
                "PMLogger",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .target(
            name: "WireGuardExtension",
            dependencies: [
                "WireGuardKit",
                "WireGuardLogging",
                "ExtensionIPC",
                "NEHelper",
                "Ergonomics",
                "Domain",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "ConnectionShared", package: "Connection"),
                .product(name: "CoreConnection", package: "Connection"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5),
            ]
        ),
        .testTarget(
            name: "WireGuardExtensionTests",
            dependencies: ["WireGuardExtension"]
        ),
        ProTUNFFITargetKind.current.target,
    ]
)
