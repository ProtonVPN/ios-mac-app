// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ExtensionIPC",
    platforms: [
        .iOS(.v15),
        .macOS(.v11),
        .tvOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ExtensionIPC",
            targets: ["ExtensionIPC"]
        ),
    ],
    dependencies: [
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ExtensionIPC",
            dependencies: ["Domain", "Ergonomics"]
        ),
        .testTarget(
            name: "ExtensionIPCTests",
            dependencies: ["ExtensionIPC"]
        ),
    ]
)
