// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum ProTUNFFITargetKind {
    // TODO: ProTUN: support uploads to S3 for public release
    #if false
        static let current: Self = .remote(
            url: "https://vpn.protondownload.com/download/protun/2.1.2_3337855.2607171442.1/protun-release.xcframework.zip",
            checksum: "fd91990551c1410b1550cf2bc8789a628e4e91c6ce671c004cee11b77271cf06"
        )
    #else
        static let current: Self = .remote(
            url: "https://nexus.protontech.ch/repository/vpn-release-candidates/protun/2.2.0_3375329.2607291218.1/protun-release.xcframework.zip",
            checksum: "cfe82cf446d415004777cf9fa4852248de7bdf75014f62a64d973d92156e49f7"
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
        .package(url: "https://github.com/mattmassicotte/Queue", from: "0.2.2"),
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
                .product(name: "Hermes", package: "Connection"),
                .product(name: "IPCDefinitions", package: "Connection"),
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "ExtensionIPC", package: "ExtensionIPC"),
                .target(name: "protun"),
                .target(name: "XPCAuditToken", condition: .when(platforms: [.macOS])),

                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Queue", package: "Queue"),
            ],
            plugins: protunExtensionPlugins
        ),
        .target(name: "XPCAuditToken"),
        ProTUNFFITargetKind.current.target,
    ]
)
