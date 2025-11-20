// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ios_app",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ios_app",
            targets: ["ios_app"]
        ),
    ],
    dependencies: [
        .package(path: "../../../external/protoncore"),

        .package(path: "../Announcement"),
        .package(path: "../Review"),
        .package(path: "../BugReport"),
        .package(path: "../Settings"),
        .package(path: "../Modals"),
        .package(path: "../Search"),
        .package(path: "../Home"),

        .package(path: "../../Core/NEHelper"),
        .package(path: "../../Core/LegacyCommon"),

        .package(path: "../../Foundations/Theme"),
        .package(path: "../../Foundations/PMLogger"),
        .package(path: "../../Foundations/Domain"),
        .package(path: "../../Foundations/Ergonomics"),
        .package(path: "../../Foundations/Strings"),
        .package(path: "../../Foundations/Timer"),

        .package(path: "../../Shared/CommonNetworking"),
        .package(path: "../../Shared/Persistence"),
        .package(path: "../../Shared/ExtensionIPC"),
        .package(path: "../../Shared/Localization"),
        .package(path: "../../Shared/Connection"),
        .package(path: "../../Shared/ConnectionInventory"),

        .package(url: "https://github.com/apple/swift-log.git", exact: "1.6.4"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/wxxsw/GSMessages", exact: "1.7.5"),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.23.1")),
        .package(url: "https://github.com/Alamofire/Alamofire", exact: "5.4.4"),
        .package(url: "https://github.com/Alamofire/AlamofireImage", exact: "4.2.0"),
        .package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.15.8"),
        .package(url: "https://github.com/pointfreeco/swift-navigation", .upToNextMajor(from: "2.3.2")),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", from: "9.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ios_app",
            dependencies: [
                "LegacyCommon",
                "Review",
                "Theme",
                "BugReport",
                "CommonNetworking",
                "PMLogger",
                "Domain",
                "Ergonomics",
                "Settings",
                "Strings",
                "Modals",
                "Persistence",
                "Announcement",
                "Search",
                "ExtensionIPC",
                "Home",
                "Localization",
                "Connection",
                "NEHelper",
                .product(name: "VPNShared", package: "NEHelper"),
                .product(name: "VPNAppCore", package: "NEHelper"),
                .product(name: "Timer", package: "Timer"),
                .product(name: "Hermes", package: "Connection"),

                .product(name: "ProtonCoreAPIClient", package: "protoncore"),
                .product(name: "ProtonCoreAccountDeletion", package: "protoncore"),
                .product(name: "ProtonCoreAccountRecovery", package: "protoncore"),
                .product(name: "ProtonCoreDataModel", package: "protoncore"),
                .product(name: "ProtonCoreDoh", package: "protoncore"),
                .product(name: "ProtonCoreEnvironment", package: "protoncore"),
                .product(name: "ProtonCoreFeatureFlags", package: "protoncore"),
                .product(name: "ProtonCoreForceUpgrade", package: "protoncore"),
                .product(name: "ProtonCoreHumanVerification", package: "protoncore"),
                .product(name: "ProtonCoreLog", package: "protoncore"),
                .product(name: "ProtonCoreLogin", package: "protoncore"),
                .product(name: "ProtonCoreLoginUI", package: "protoncore"),
                .product(name: "ProtonCoreNetworking", package: "protoncore"),
                .product(name: "ProtonCoreObservability", package: "protoncore"),
                .product(name: "ProtonCorePasswordChange", package: "protoncore"),
                .product(name: "ProtonCorePayments", package: "protoncore"),
                .product(name: "ProtonCorePaymentsUI", package: "protoncore"),
                .product(name: "ProtonCorePaymentsV2", package: "protoncore"),
                .product(name: "ProtonCorePaymentsUIV2", package: "protoncore"),
                .product(name: "ProtonCorePushNotifications", package: "protoncore"),
                .product(name: "ProtonCoreServices", package: "protoncore"),
                .product(name: "ProtonCoreTelemetry", package: "protoncore"),
                .product(name: "ProtonCoreUIFoundations", package: "protoncore"),
                .product(name: "GoLibsCryptoVPNPatchedGo", package: "protoncore"),

                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "GSMessages", package: "GSMessages"),
                .product(name: "Sharing", package: "swift-sharing"),
                .product(name: "Alamofire", package: "Alamofire"),
                .product(name: "AlamofireImage", package: "AlamofireImage"),
                .product(name: "SDWebImage", package: "SDWebImage"),
                .product(name: "SwiftUINavigation", package: "swift-navigation"),
                .product(name: "OHHTTPStubs", package: "OHHTTPStubs"),
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs"),
            ],
            resources: [.process("Resources")],
        ),
        .testTarget(
            name: "ios_appTests",
            dependencies: [
                "ios_app",
                .product(name: "VPNSharedTesting", package: "NEHelper"),
                .product(name: "TimerMock", package: "Timer"),
            ]
        ),
    ]
)
