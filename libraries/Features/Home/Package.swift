// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Home",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Home",
            targets: ["Home"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Modals"),
        .package(path: "../NetShield"),
        .package(path: "../ConnectionDetails"),
        .package(path: "../Announcement"),
        .package(path: "../Payments"),
        .package(path: "../PCAP"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/ConnectionInventory"),

        .package(url: "https://github.com/apple/swift-algorithms", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI.git", from: "3.0.0"),
        .package(url: "https://github.com/airbnb/lottie-spm", .upToNextMajor(from: "4.6.0")),
        // GEOS C library (PostGIS engine), used only by the offline MapBaker tool to triangulate the
        // globe geometry. Not reachable from the "Home" product, so it never links into the app.
        .package(url: "https://github.com/GEOSwift/geos", .upToNextMajor(from: "9.0.0")),
    ],
    targets: [
        .target(
            name: "Home",
            dependencies: [
                .target(name: "Home-iOS", condition: .when(platforms: [.iOS])),
                .target(name: "Home-macOS", condition: .when(platforms: [.macOS])),
            ]
        ),
        .target(
            name: "HomeShared",
            dependencies: [
                "CommonNetworking",
                "Connection",
                .product(name: "ExtensionSync", package: "Connection"),
                "Localization",
                "Persistence",
                "Theme",
                "SharedViews",
                "NetShield",
                "Ergonomics",
                "Announcement",
                "ConnectionInventory",
                "ConnectionDetails",
                "Domain",
                "PMLogger",
                "Strings",
                "PCAP",
                "MapModel",
                .product(name: "Modals", package: "Modals"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "Payments", package: "Payments", condition: .when(platforms: [.iOS])),
                .product(name: "PaymentsShared", package: "Payments", condition: .when(platforms: [.iOS])),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "CoreConnection", package: "Connection"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),

                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "SDWebImageSwiftUI", package: "SDWebImageSwiftUI"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            exclude: [
                "swiftgen.yml",
                "Resources/BlankMap-World.svg", // source for MapBaker; not bundled (the app loads world-globe.bin)
            ],
            resources: [
                .copy("Resources/world-globe.bin"), // 3-D globe geometry, loaded straight into Metal buffers
                .process("Resources/widget-ios-v4.json"),
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .target(
            name: "Home-iOS",
            dependencies: [
                "HomeShared",
                .product(name: "Payments", package: "Payments"),
            ]
        ),
        .target(
            name: "Home-macOS",
            dependencies: [
                "HomeShared",
            ],
            resources: []
        ),
        // Leaf module with no UIKit/iOS deps so it can be shared by both HomeShared (the app) and the
        // MapBaker command-line tool: the binary map format + its encode/decode live here, keeping the
        // tool's encoder and the app's decoder from drifting apart.
        .target(
            name: "MapModel"
        ),
        // Offline tool that converts the source SVG into Resources/world-globe.bin. Run it whenever the
        // SVG changes: `swift run MapBaker` (from this package directory), then commit the new binary.
        // Not reachable from the "Home" product, so it never builds as part of the app.
        .executableTarget(
            name: "MapBaker",
            dependencies: [
                "MapModel",
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "geos", package: "geos"),
            ]
        ),
        .testTarget(
            name: "HomeTests",
            dependencies: [
                "HomeShared",
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "HomeFastSnapshotTests",
            dependencies: [
                "Home",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
        .testTarget(
            name: "HomeSlowSnapshotTests",
            dependencies: [
                "Home",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
            ]
        ),
    ]
)
