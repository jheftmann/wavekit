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
            exclude: ["Resources/Assets.xcassets", "WaveKit.entitlements"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
