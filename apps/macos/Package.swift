// swift-tools-version: 5.9
import PackageDescription

// Pomo — a native macOS HUD Pomodoro timer.
//
// Consumes the local HudsonKit (the "Hudson" Swift package) for design tokens
// and window chrome. Only the dependency-free core products are used
// (HudsonUI + HudsonShell), so the build needs no network access — but always
// build with `HUDSONKIT_WITH_VOICE=0` so Hudson's manifest does not pull in the
// optional `vox`/`Termini` git dependencies. scripts/run-app.sh sets this.
let package = Package(
    name: "Pomo",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // HudsonKit lives as a sibling checkout of this monorepo:
        // <dev>/hudson, reached from apps/macos via three levels up.
        .package(name: "Hudson", path: "../../../hudson")
    ],
    targets: [
        .executableTarget(
            name: "Pomo",
            dependencies: [
                .product(name: "HudsonUI", package: "Hudson"),
                .product(name: "HudsonShell", package: "Hudson"),
            ],
            path: "Sources/Pomo"
        )
    ]
)
