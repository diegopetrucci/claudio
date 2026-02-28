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
    dependencies: [
        .package(path: "../SearchTool"),
    ],
    targets: [
        .target(
            name: "ToolExecutor",
            dependencies: [
                "SearchTool",
            ]
        ),
        .testTarget(
            name: "ToolExecutorTests",
            dependencies: [
                .target(name: "ToolExecutor"),
                "SearchTool",
            ]
        ),
    ]
)
