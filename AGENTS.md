# AGENTS.md

## Where to work

**`apps/macos` is the primary, active implementation.** It's the native macOS
SwiftUI menu-bar HUD app. New features and fixes go here.

`apps/ios` and `apps/watch` are native companion apps (SwiftUI / watchOS).

`apps/cli` is the published `@arach/pomo` npm package — shell control, live
TUI, and `pomo://` command forwarding.

**`landing/`** (top level) is the marketing site at
**[pomo.arach.dev](https://pomo.arach.dev)** — a Next.js app deployed to GitHub
Pages. Use **bun** for it (`bun install`, `bun run dev`, `bun run build`), not
npm or pnpm.

See [README.md](README.md) for the full app matrix and build commands.