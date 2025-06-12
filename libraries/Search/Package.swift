// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Search",
    defaultLocalization: "en",
    platforms: [.iOS(.v16)],
    products: [
        .library(
            name: "Search",
            targets: ["Search"]),
    ],
    dependencies: [
        .package(path: "../Foundations/Strings"),
        .package(path: "../Foundations/Theme"),
        .package(url: "https://github.com/pointfreeco/swift-overture", exact: "0.5.0"),
    ],
    targets: [
        .target(
            name: "Search",
            dependencies: [
                "Theme",
                "Strings",
                .product(name: "Overture", package: "swift-overture"),
            ],
            resources: [
                .process("Storyboard.storyboard"),
                .process("Views/PlaceholderView.xib"),
                .process("Views/PlaceholderItemView.xib"),
                .process("Views/RecentSearchesHeaderView.xib"),
                .process("Views/NoResultsView.xib"),
                .process("Views/SearchSectionHeaderView.xib"),
                .process("Cells/RecentSearchCell.xib"),
                .process("Cells/CountryCell.xib"),
                .process("Cells/ServerCell.xib"),
                .process("Cells/UpsellCell.xib"),
                .process("Cells/CityCell.xib"),
                .process("Assets.xcassets"),
            ]),
        .testTarget(
            name: "SearchTests",
            dependencies: [
                "Search",
                .product(name: "Overture", package: "swift-overture"),
            ]
        ),
    ]
)
