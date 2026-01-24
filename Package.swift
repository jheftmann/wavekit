// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SurflineFavorites",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SurflineFavorites",
            path: "SurflineFavorites",
            exclude: ["Resources/Assets.xcassets", "SurflineFavorites.entitlements"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ]
)
