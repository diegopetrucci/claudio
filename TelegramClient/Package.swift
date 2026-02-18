// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TelegramClient",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TelegramClient",
            targets: ["TelegramClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(
            name: "TelegramClient",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
            ]
        ),
        .testTarget(
            name: "TelegramClientTests",
            dependencies: [
                .target(name: "TelegramClient"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
            ]
        ),
    ]
)

