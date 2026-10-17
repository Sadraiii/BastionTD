// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BastionTD",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "BastionTD",
            targets: ["BastionTD"]
        ),
    ],
    targets: [
        .target(
            name: "BastionTD",
            path: "TowerDefense",
            // Asset catalogs need Xcode's actool; xtool takes the icon from xtool.yml instead.
            exclude: ["Assets.xcassets"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
