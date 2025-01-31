// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Announcement",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Announcement",
            targets: ["Announcement"]),
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Domain"),
        .package(path: "../Shared/CommonNetworking"),
    ],
    targets: [
        .target(
            name: "Announcement",
            dependencies: [
                "Strings",
                "Domain",
                "CommonNetworking",
            ]),
        .testTarget(
            name: "AnnouncementTests",
            dependencies: ["Announcement"]
        ),
    ]
)
