// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnthropicClient",
    platforms: [
       .macOS(.v13)
    ],
    products: [
        .library(
            name: "AnthropicClient",
            targets: ["AnthropicClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/jamesrochabrun/SwiftAnthropic.git", from: "2.2.1"),
    ],
    targets: [
        .target(
            name: "AnthropicClient",
            dependencies: [
                .product(name: "SwiftAnthropic", package: "SwiftAnthropic"),
            ],
        ),
        .testTarget(
            name: "AnthropicClientTests",
            dependencies: ["AnthropicClient"]
        ),
    ]
)
