// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "TelegramPollingLifecycleHandler",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TelegramPollingLifecycleHandler",
            targets: ["TelegramPollingLifecycleHandler"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(path: "../TelegramClient"),
    ],
    targets: [
        .target(
            name: "TelegramPollingLifecycleHandler",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "TelegramClient",
            ]
        ),
        .testTarget(
            name: "TelegramPollingLifecycleHandlerTests",
            dependencies: [
                .target(name: "TelegramPollingLifecycleHandler"),
            ]
        ),
    ]
)
