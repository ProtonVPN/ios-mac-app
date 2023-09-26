// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LegacyCommon",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "LegacyCommon",
            targets: ["LegacyCommon"]
        ),
        /*
         Future: When SPM decides to be a mature software product, move the Mocks here.
         macOS unit tests refused to link this target, even though every other target
         was fine with it:
        .library(
            name: "LegacyCommonTestSupport",
            targets: ["LegacyCommonTestSupport"]
        ),
        */
    ],
    dependencies: [
        // External packages regularly upstreamed by our project (imported as submodules)
        .package(path: "../../external/protoncore"),
        .package(path: "../../external/tunnelkit"),

        // Local packages
        .package(path: "../BugReport"),
        .package(path: "../ConnectionDetails"),
        .package(path: "../Modals"),
        .package(path: "../Home"),
        .package(path: "../LocalFeatureFlags"),
        .package(path: "../NEHelper"),
        .package(path: "../PMLogger"),
        .package(path: "../SharedViews"),
        .package(path: "../Settings"),
        .package(path: "../Strings"),
        .package(path: "../Theme"),
        .package(path: "../Timer"),

        // External dependencies
        .github("apple", repo: "swift-collections", .upToNextMajor(from: "1.0.4")),
        .github("ashleymills", repo: "Reachability.swift", exact: "5.1.0"),
        .github("getsentry", repo: "sentry-cocoa", exact: "8.9.0"),
        .github("kishikawakatsumi", repo: "KeychainAccess", exact: "3.2.1"),
        .github("pointfreeco", repo: "swift-clocks", .upToNextMajor(from: "1.0.0")),
        .github("pointfreeco", repo: "swift-composable-architecture", .upToNextMajor(from: "1.0.0")),
        .github("pointfreeco", repo: "swift-dependencies", .upToNextMajor(from: "1.0.0")),
        .github("pointfreeco", repo: "swiftui-navigation", exact: "1.0.0"),
        .github("SDWebImage", repo: "SDWebImage", .upTo("5.16.0")),
        .github("ProtonMail", repo: "TrustKit", revision: "d107d7cc825f38ae2d6dc7c54af71d58145c3506"),
        .github("almazrafi", repo: "DictionaryCoder", exact: "1.1.0"),
//        .github("realm", repo: "SwiftLint", exact: "0.52.4"),
    ],
    targets: [
        .target(
            name: "LegacyCommon",
            dependencies: [
                // Local
                "Strings",
                "Theme",
                "Home",
                "Modals",
                "Settings",
                "BugReport",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),

                // Todo: move these to LegacyCommonTestSupport, if we ever can
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "TimerMock", package: "Timer"),

                // Core code
                .core(module: "AccountDeletion"),
                .core(module: "APIClient"),
                .core(module: "Authentication"),
                .core(module: "Challenge"),
                .core(module: "DataModel"),
                .core(module: "Doh"),
                .core(module: "Environment"),
                .core(module: "FeatureSwitch"),
                .core(module: "ForceUpgrade"),
                .core(module: "Foundations"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),
                .core(module: "HumanVerification"),
                .core(module: "Log"),
                .core(module: "Login"),
                .core(module: "Networking"),
                .core(module: "Payments"),
                .core(module: "Services"),
                .core(module: "UIFoundations"),
                .core(module: "Utilities"),

                // External
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Reachability", package: "Reachability.swift"),
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "Sentry", package: "sentry-cocoa"),
                .product(name: "TrustKit", package: "TrustKit"),
                .product(name: "TunnelKit", package: "TunnelKit"),
                .product(name: "TunnelKitOpenVPN", package: "TunnelKit"),
                .product(name: "DictionaryCoder", package: "DictionaryCoder")
            ],
            plugins: [
//                .plugin(name: "SwiftLintPlugin", package: "SwiftLint")
            ]
        ),
        /*
        .target(
            name: "LegacyCommonTestSupport",
            dependencies: [
                "LegacyCommon",
                "Strings",
                "Home",
                .product(name: "TimerMock", package: "Timer"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),

                .core(module: "Authentication"),
                .core(module: "DataModel"),
                .core(module: "Foundations"),
                .core(module: "Networking"),
                .core(module: "Services"),
            ]
        ),
        */
        .testTarget(
            name: "LegacyCommonTests",
            dependencies: [
                "LegacyCommon",
                .product(name: "TimerMock", package: "Timer"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .core(module: "TestingToolkitUnitTestsCore")
            ],
            resources: [
                .copy("Resources/test_log_1.log"),
                .copy("Resources/test_log_2.log"),
                .copy("Resources/ServerManagerTestServers.json")
            ]
        ),
    ]
)

extension Range<PackageDescription.Version> {
    static func upTo(_ version: Version) -> Self {
        "0.0.0"..<version
    }
}

extension String {
    static func githubUrl(_ author: String, _ repo: String) -> Self {
        "https://github.com/\(author)/\(repo)"
    }
}

extension PackageDescription.Package.Dependency {
    static func github(_ author: String, repo: String, exact version: Version) -> Package.Dependency {
        .package(url: .githubUrl(author, repo), exact: version)
    }

    static func github(_ author: String, repo: String, revision: String) -> Package.Dependency {
        .package(url: .githubUrl(author, repo), revision: revision)
    }

    static func github(_ author: String, repo: String, _ range: Range<Version>) -> Package.Dependency {
        .package(url: .githubUrl(author, repo), range)
    }
}

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
