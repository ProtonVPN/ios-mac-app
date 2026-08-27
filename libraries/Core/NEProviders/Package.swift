// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum ProTUNFFITargetKind {
    private static let artifact = "2.4.0_3473951.2608271041.1/protun-release.xcframework.zip"
    private static let checksum = "6b098f459440d3c0e3fcab9dfbfb9a6fca7d029451ee37b46317a5530d4e0df4"

    private static var url: String {
        guard let nexus = Context.environment["CI_NEXUS_URL"], !nexus.isEmpty else {
            return "https://vpn.protondownload.com/download/protun/\(artifact)"
        }
        let base = nexus.hasSuffix("/") ? String(nexus.dropLast()) : nexus
        return "\(base)/repository/vpn-release-candidates/protun/\(artifact)"
    }

    static let current: Self = .remote(url: url, checksum: checksum)

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
                .product(name: "ExtensionSync", package: "Connection"),
                .product(name: "Hermes", package: "Connection"),
                .product(name: "IPCDefinitions", package: "Connection"),
                .product(name: "IPCErgonomics", package: "Ergonomics"),
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "ExtensionIPC", package: "ExtensionIPC", condition: .when(platforms: [.macOS])),
                .target(name: "protun"),
                .target(name: "XPCAuditToken", condition: .when(platforms: [.macOS])),

                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Queue", package: "Queue"),
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ],
            plugins: protunExtensionPlugins
        ),
        .target(name: "XPCAuditToken"),
        ProTUNFFITargetKind.current.target,
    ]
)
