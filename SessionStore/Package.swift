// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "SessionStore",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "SessionStore",
            targets: ["SessionStore"]
        ),
    ],
    targets: [
        .target(
            name: "SessionStore"
        ),
        .testTarget(
            name: "SessionStoreTests",
            dependencies: [
                .target(name: "SessionStore"),
            ]
        ),
    ]
)
