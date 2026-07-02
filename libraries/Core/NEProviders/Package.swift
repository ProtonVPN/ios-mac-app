// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum ProTUNFFITargetKind {
    // TODO: ProTUN: support uploads to S3 for public release
    #if false
        static let current: Self = .remote(
            url: "https://nexus.protontech.ch/repository/vpn-protun/master/protun-debug.xcframework.zip",
            checksum: "dd73fc3df940a5d1b48fb6438d03799e0f2fac732a0a8a4668b664396778f464"
        )
    #else
        static let current: Self = .remote(
            url: "https://nexus.protontech.ch/repository/vpn-release-candidates/protun/2.1.1_3321564.2607101847.1/protun-release.xcframework.zip",
            checksum: "3db1449d720d783237a17480b28fd4a1710cef1f686171a701010844309936d7"
        )
    #endif

    case local
    case remote(url: String, checksum: String)

    var target: PackageDescription.Target {
        switch self {
        case .local:
            .binaryTarget(name: "protun", path: "Frameworks/protun.xcframework")
        case let .remote(url, checksum):
            .binaryTarget(name: "protun", url: url, checksum: checksum)
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
    ],
    dependencies: [
        .package(name: "vpn-core-apple", path: "../../../external/vpn-core-apple"),

        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/ExtensionIPC"),

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
                "PMLogger",
                .product(name: "ConnectionShared", package: "Connection"),
                .product(name: "VPNCoreCommon", package: "vpn-core-apple"),
                .product(name: "VPNCoreTypes", package: "vpn-core-apple"),
                .product(name: "VPNCoreExtension", package: "vpn-core-apple"),
                .product(name: "ExtensionSync", package: "Connection"),
                .product(name: "IPCDefinitions", package: "Connection"),
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "ExtensionIPC", package: "ExtensionIPC"),
                .target(name: "protun"),
                .target(name: "XPCAuditToken", condition: .when(platforms: [.macOS])),

                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ],
            plugins: protunExtensionPlugins
        ),
        .target(name: "XPCAuditToken"),
        ProTUNFFITargetKind.current.target,
    ]
)
