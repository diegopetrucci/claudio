// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "claudio",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        .package(path: "AnthropicClient"),
        .package(path: "SessionStore"),
        .package(path: "TelegramClient"),
        .package(path: "TelegramBotService"),
        .package(path: "TelegramPollingLifecycleHandler"),
    ],
    targets: [
        .executableTarget(
            name: "claudio",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                "AnthropicClient",
                "SessionStore",
                "TelegramClient",
                "TelegramBotService",
                "TelegramPollingLifecycleHandler",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "claudioTests",
            dependencies: [
                .target(name: "claudio"),
                .product(name: "VaporTesting", package: "vapor"),
                "AnthropicClient",
                "SessionStore",
                "TelegramClient",
                "TelegramBotService",
                "TelegramPollingLifecycleHandler",
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
