// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

enum ProTUNFFITargetKind {
    static let current: Self = .remote(
        url: "https://nexus.protontech.ch/repository/vpn-protun/master/protunFFI.xcframework.zip",
        checksum: "c770dc20d2f23815cd030f8c7b982390aab1e9a7ef16caec6b57132d561d381f"
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

        .package(path: "../NEHelper"),

        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),

        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Connection"),

        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", exact: "4.2.2"),

        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.2"),
    ],
    targets: [
        .target(
            name: "ProTUNExtension",
            dependencies: [
                "Domain",
                "NEHelper",
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .target(name: "protunFFI", condition: .when(platforms: [.iOS])),
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
                "KeychainAccess",
                "Ergonomics",
                "Domain",
                .product(name: "VPNShared", package: "NEHelper"),
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
