// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)],
    products: [
        .library(
            name: "BugReport",
            targets: ["BugReport"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BugReport",
            dependencies: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "BugReportTests",
            dependencies: ["BugReport"],
            resources: [
                .process("example1.json"),
            ]),
        
    ]
)
