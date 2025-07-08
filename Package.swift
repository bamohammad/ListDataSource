// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DataSource",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "DataSource",
            targets: ["DataSource"]),
    ],
    targets: [
        .target(
            name: "DataSource"),
        .testTarget(
            name: "DataSourceTests",
            dependencies: ["DataSource"]
        ),
    ]
)
