// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WaveKit",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "WaveKit",
            path: "WaveKit",
            exclude: ["WaveKit.entitlements", "Resources/Assets.xcassets"],
            resources: [
                .copy("Resources/Images")
            ],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
