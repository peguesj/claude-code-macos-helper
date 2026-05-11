// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeHelper",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "ClaudeHelper", targets: ["ClaudeHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
        .package(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", from: "1.1.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.29.0"),
    ],
    targets: [
        .executableTarget(
            name: "ClaudeHelper",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
                .product(name: "LaunchAtLogin", package: "LaunchAtLogin-Modern"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ClaudeHelper",
            resources: [
                .copy("Resources/Info.plist"),
                .process("Resources/Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "ClaudeHelperTests",
            dependencies: ["ClaudeHelper"],
            path: "Tests/ClaudeHelperTests"
        ),
    ]
)
