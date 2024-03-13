// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedViews",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)],
    products: [
        .library(
            name: "SharedViews",
            targets: ["SharedViews"]
        ),
    ],
    dependencies: [
        // Local
        .package(path: "../../external/protoncore"),
        .package(path: "../Foundations/Theme"),
        .package(path: "../Foundations/Ergonomics"),
        .package(path: "../NEHelper"),
        .package(path: "../Foundations/Strings"),
        
        // 3rd party
        .package(
          url: "https://github.com/pointfreeco/swift-dependencies.git",
          from: "1.2.1"
        ),
    ],
    targets: [
        .target(
            name: "SharedViews",
            dependencies: [
                .core(module: "Utilities"),
                "Theme",
                "Ergonomics",
                "Strings",
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        )
    ]
)

extension PackageDescription.Target.Dependency {
    static func core(module: String) -> Self {
        .product(name: "ProtonCore\(module)", package: "protoncore")
    }
}
