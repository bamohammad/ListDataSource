import PackageDescription

let package = Package(
    name: "ListDataSource",
    platforms: [
        .iOS(.v14), .macOS(.v12)
    ],
    products: [
        .library(name: "ListDataSource", targets: ["ListDataSource"])
    ],
    targets: [
        .target(
            name: "ListDataSource",
            // point to the subfolder where Sources actually live
            path: "ListDataSource/Sources/ListDataSource"
        ),
        .testTarget(
            name: "ListDataSourceTests",
            dependencies: ["ListDataSource"],
            path: "ListDataSource/Tests/ListDataSourceTests"
        )
    ]
)
