// swift-tools-version: 5.9
import PackageDescription

// Pomo — a native macOS HUD Pomodoro timer.
//
// HudsonKit (design tokens + window chrome) is consumed as prebuilt, closed-source
// binary XCFrameworks published publicly at:
//   https://github.com/arach/hudsonkit-xcframework
// so this repo builds standalone — no private Hudson source checkout required.
// First resolve downloads the release artifacts; subsequent builds are cached.
let package = Package(
    name: "Pomo",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/arach/hudsonkit-xcframework.git", exact: "0.3.2")
    ],
    targets: [
        .target(
            name: "PomoShared",
            dependencies: [
                .product(name: "HudsonUI", package: "hudsonkit-xcframework"),
                .product(name: "HudsonShell", package: "hudsonkit-xcframework"),
            ],
            path: "Sources/PomoShared",
            resources: [
                .copy("Resources/PomoAmpDefaultSkin")
            ]
        ),
        .executableTarget(
            name: "Pomo",
            dependencies: ["PomoShared"],
            path: "Sources/Pomo"
        ),
        .executableTarget(
            name: "PomoAmp",
            dependencies: ["PomoShared"],
            path: "Sources/PomoAmp"
        )
    ]
)
