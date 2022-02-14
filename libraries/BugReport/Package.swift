// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BugReport",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12), // On iOS < 14, Creator will return nil, so the app can use old, compatible BugReport.
        .macOS(.v10_15)], // On macOS < 11, Creator will return nil, so the app can use old, compatible BugReport.
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
