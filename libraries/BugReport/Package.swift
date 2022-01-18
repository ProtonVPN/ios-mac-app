// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12), // On iOS < 14, Creator will return nil, so the app can use old, compatible BugReport.
        .macOS(.v11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "BugReport",
            targets: ["BugReport"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "BugReport",
            dependencies: [],
            resources: []
        ),
        .testTarget(
            name: "BugReportTests",
            dependencies: ["BugReport"],
            resources: [
                .process("example1.json"),
            ]),
        
    ]
)
