// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "AppLifecycleHandler",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "AppLifecycleHandler",
            targets: ["AppLifecycleHandler"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(path: "../TelegramClient"),
    ],
    targets: [
        .target(
            name: "AppLifecycleHandler",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                "TelegramClient",
            ]
        ),
        .testTarget(
            name: "AppLifecycleHandlerTests",
            dependencies: [
                .target(name: "AppLifecycleHandler"),
                .product(name: "Vapor", package: "vapor"),
                "TelegramClient",
            ]
        ),
    ]
)
