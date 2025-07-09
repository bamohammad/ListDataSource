// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ListDataSource",
    defaultLocalization: "en",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "ListDataSource",
            targets: ["ListDataSource"]),
    ],
    targets: [
        .target(
            name: "ListDataSource"),
        .testTarget(
            name: "ListDataSourceTests",
            dependencies: ["ListDataSource"]
        ),
    ]
)
