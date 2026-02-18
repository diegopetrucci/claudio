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
        .package(path: "TelegramClient"),
    ],
    targets: [
        .executableTarget(
            name: "claudio",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                "AnthropicClient",
                "TelegramClient",
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "claudioTests",
            dependencies: [
                .target(name: "claudio"),
                .product(name: "VaporTesting", package: "vapor"),
                "AnthropicClient",
                "TelegramClient",
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
