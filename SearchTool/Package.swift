// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SearchTool",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SearchTool",
            targets: ["SearchTool"]
        ),
    ],
    targets: [
        .target(
            name: "SearchTool"
        ),
        .testTarget(
            name: "SearchToolTests",
            dependencies: [
                .target(name: "SearchTool"),
            ]
        ),
    ]
)
