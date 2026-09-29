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
        // Platform-agnostic features
        .library(
            name: "HomeShared",
            targets: ["HomeShared"]
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
        .package(path: "../../Foundations/WidgetReload"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Strings"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/SharedViews"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/ConnectionInventory"),
        .package(path: "../../Shared/Telemetry"),

        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.1.4")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.24.1")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.11.0")),
        .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.9.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-clocks", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/pointfreeco/combine-schedulers", .upToNextMajor(from: "1.0.3")),
        .package(url: "https://github.com/airbnb/lottie-spm", .upToNextMajor(from: "4.6.0")),
        // GEOS and SVGView not used at runtime, only used by the MapBaker command line tool to generate the 3D model.
        .package(url: "https://github.com/GEOSwift/geos", .upToNextMajor(from: "9.0.0")),
        .package(url: "https://github.com/exyte/SVGView", .upToNextMajor(from: "1.0.6")),
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
                "WidgetReload",
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
                "Telemetry",
                "PCAP",
                "MapModel",
                "MapShaderTypes",
                .product(name: "Modals", package: "Modals"),
                .product(name: "ModalsServices", package: "Modals"),
                .product(name: "Payments", package: "Payments", condition: .when(platforms: [.iOS])),
                .product(name: "PaymentsShared", package: "Payments", condition: .when(platforms: [.iOS])),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "Triangulation", package: "Ergonomics"), // for the map view
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "CoreConnection", package: "Connection"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),

                .product(name: "Lottie", package: "lottie-spm"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "CombineSchedulers", package: "combine-schedulers"),
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            exclude: [
                "swiftgen.yml",
                "Resources/BlankMap-World.svg", // MapBaker's input; not bundled, the app loads world-globe.bin
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
                .product(name: "Modals", package: "Modals"),
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
        // Struct layouts shared between the CPU and the GPU using a simple header file so Metal can consume it.
        .target(
            name: "MapShaderTypes",
            publicHeadersPath: "include"
        ),
        // Model objects shared between the actual view model and the MapBaker command-line tool.
        .target(
            name: "MapModel",
            dependencies: [
                "Ergonomics",
                "MapShaderTypes", // the border-segment layout is defined in the shared C header
                .product(name: "Triangulation", package: "Ergonomics"),
            ]
        ),
        .executableTarget(
            name: "MapBaker",
            dependencies: [
                "Domain",
                "MapModel",
                .product(name: "Ergonomics", package: "Ergonomics"),
                .product(name: "SVGView", package: "SVGView"),
                .product(name: "geos", package: "geos"),
                .product(name: "Triangulation", package: "Ergonomics"),
            ],
            exclude: [
                // Records which Natural Earth release the outlines came from. Kept beside them in the repo, but
                // nothing reads it, so it stays out of the built tool.
                "Resources/ne_50m_admin_0_countries.VERSION.txt",
            ],
            resources: [
                // Natural Earth reference country polygons. The bake calibrates the SVG's geography against them.
                .copy("Resources/ne_50m_admin_0_countries.shp"),
            ]
        ),
        // Test targets link only the target under test plus test-support products that are not
        // transitively available from it (linking a transitive dependency again produces duplicate-class
        // warnings at runtime); modules like Ergonomics, MapModel, and Triangulation import fine through
        // the tested target.
        .testTarget(
            name: "HomeTests",
            dependencies: [
                "HomeShared",
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "NetworkingErgonomics", package: "Ergonomics"),
                .product(name: "PersistenceTestSupport", package: "Persistence"),
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
        .testTarget(
            name: "HomeSlowSnapshotTests",
            dependencies: [
                "Home",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
                .product(name: "DomainTestSupport", package: "Domain"),
                .product(name: "DependenciesTestSupport", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "MapModelTests",
            dependencies: [
                "MapModel",
                .product(name: "TestingErgonomics", package: "Ergonomics"),
            ]
        ),
    ]
)
