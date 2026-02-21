// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "ToolExecutor",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ToolExecutor",
            targets: ["ToolExecutor"]
        ),
    ],
    targets: [
        .target(
            name: "ToolExecutor"
        ),
        .testTarget(
            name: "ToolExecutorTests",
            dependencies: [
                .target(name: "ToolExecutor"),
            ]
        ),
    ]
)
