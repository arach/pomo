# AGENTS.md

## Where to work

**`apps/macos` is the primary, active implementation.** It's the native macOS
SwiftUI menu-bar HUD app. New features and fixes go here.

**`apps/tauri` is reference only.** It's the original React + TypeScript + Tauri
app Pomo grew out of. We're on native macOS now — do **not** add features there.
Read it for history or to port behavior, but don't build new work in it.

**Exception:** `apps/tauri/landing` is the active marketing site and remains in scope for landing-page work.

`apps/ios` and `apps/watch` are native companion apps (SwiftUI / watchOS).

See [README.md](README.md) for the full app matrix and build commands.
