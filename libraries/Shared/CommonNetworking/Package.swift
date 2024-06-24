// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonNetworking",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v17),
    ],
    products: [
        .library(name: "CommonNetworking", targets: ["CommonNetworking"]),
        .library(name: "CommonNetworkingTestSupport", targets: ["CommonNetworkingTestSupport"]),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Shared/NEHelper"),
        .github("ProtonMail", repo: "TrustKit", revision: "d107d7cc825f38ae2d6dc7c54af71d58145c3506"),
        .github("pointfreeco", repo: "swift-dependencies", .upToNextMajor(from: "1.2.1")),
        .github("pointfreeco", repo: "xctest-dynamic-overlay", .upToNextMajor(from: "1.1.0")),
    ],
    targets: [
        .target(
            name: "CommonNetworking",
            dependencies: [
                "PMLogger",
                .product(name: "VPNAppCore", package: "NEHelper"), // UnauthKeychain
                .product(name: "VPNShared", package: "NEHelper"), // AuthKeychain

                // Core/Accounts
                .core(module: "Authentication"),
                .core(module: "Networking"),
                .core(module: "Doh"),

                // External
                .product(name: "TrustKit", package: "TrustKit"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "XCTestDynamicOverlay", package: "xctest-dynamic-overlay"),
            ]
        ),
        .target(
            name: "CommonNetworkingTestSupport",
            dependencies: ["CommonNetworking"]
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
