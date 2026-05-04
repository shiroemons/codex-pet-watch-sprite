// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "CodexPetWatchSprite",
    platforms: [
        .iOS(.v15),
        .watchOS(.v8),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "CodexPetWatchSprite",
            targets: ["CodexPetWatchSprite"]
        )
    ],
    targets: [
        .target(
            name: "CodexPetWatchSprite",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "CodexPetWatchSpriteTests",
            dependencies: ["CodexPetWatchSprite"]
        )
    ],
    swiftLanguageModes: [.v6]
)
