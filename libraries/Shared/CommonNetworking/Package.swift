// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonNetworking",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(name: "CommonNetworking", targets: ["CommonNetworking"]),
        .library(name: "CommonNetworkingTestSupport", targets: ["CommonNetworkingTestSupport"])
    ],
    dependencies: [
        // External packages regularly upstreamed by our project (imported as submodules)
        .package(path: "../../../external/protoncore"),

        // Local packages
        .package(path: "../../Foundations/PMLogger"),

        // External dependencies
        .github("pointfreeco", repo: "swift-dependencies", .upToNextMajor(from: "1.2.1")),
    ],
    targets: [
        .target(
            name: "CommonNetworking",
            dependencies: [
                "PMLogger",

                // Core/Accounts
                .core(module: "Networking"),
                .core(module: "Doh"),

                // External
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "CommonNetworkingTestSupport",
            dependencies: ["CommonNetworking"]
        ),
        .testTarget(
            name: "CommonNetworkingTests",
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
