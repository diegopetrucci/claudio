// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "TelegramBotService",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "TelegramBotService",
            targets: ["TelegramBotService"]
        ),
    ],
    dependencies: [
        .package(path: "../AnthropicClient"),
        .package(path: "../SessionStore"),
        .package(path: "../TelegramClient"),
    ],
    targets: [
        .target(
            name: "TelegramBotService",
            dependencies: [
                "AnthropicClient",
                "SessionStore",
                "TelegramClient",
            ]
        ),
        .testTarget(
            name: "TelegramBotServiceTests",
            dependencies: [
                .target(name: "TelegramBotService"),
                "SessionStore",
            ]
        ),
    ]
)
