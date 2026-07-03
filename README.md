# Pomo

A Pomodoro timer, across platforms — a native **macOS** HUD app (the primary
implementation today), plus native **iOS** and **watchOS** companions, a
**CLI** for shell and agent control, and a marketing site at
**[pomo.arach.dev](https://pomo.arach.dev)**. One monorepo, organized by app.

## Apps

| App | Platform | Stack | Status |
| --- | --- | --- | --- |
| [`apps/macos`](apps/macos) | macOS | SwiftUI + HudsonKit | **Primary · active** |
| [`apps/cli`](apps/cli) | macOS | Node.js · `@arach/pomo` | CLI + live TUI |
| [`apps/ios`](apps/ios) | iOS | SwiftUI | Native companion |
| [`apps/watch`](apps/watch) | watchOS (+ iOS) | SwiftUI · WatchConnectivity · App Intents | Native companion |
| [`landing`](landing) | Web | Next.js · bun | Marketing site |

### macOS — [`apps/macos`](apps/macos) · primary

Menu-bar HUD timer: a hotkey-summoned frosted panel, swappable **watchfaces**
(including the engineering-drawing **Blueprint** face), tunable **backdrop blur**,
background audio, and a `pomo://` URL scheme for agent control. The macOS app
ships with **Pomo Amp** nested inside it: a small YouTube music-player companion
with its own menu-bar lifecycle and custom HTML skins.

```sh
cd apps/macos
scripts/run-app.sh            # build dist/Pomo.app and launch
scripts/run-app.sh --no-open  # build only
scripts/run-app.sh --debug    # faster local build
scripts/run-app.sh --amp --debug  # build and launch Pomo Amp
scripts/build-dmg.sh --local  # build a one-app DMG with nested Pomo Amp
```

No private checkout needed — HudsonKit is consumed as a public, prebuilt **binary**
package ([`hudsonkit-xcframework`](https://github.com/arach/hudsonkit-xcframework)),
fetched on first build. More build, signing, and Gatekeeper dequarantine commands
are in [`apps/macos/README.md`](apps/macos/README.md).

### CLI — [`apps/cli`](apps/cli) · `@arach/pomo`

Control and install Pomo from the shell or an agent. Live ANSI terminal UI,
`pomo://` commands, and JSON state reads. Published independently of the macOS
app — see **`cli-v*`** tags for npm releases (currently **0.3.6** in tree;
registry may be ahead until the next tag publish).

```sh
npx @arach/pomo install
npx @arach/pomo start
npx @arach/pomo status
```

See [`apps/cli/README.md`](apps/cli/README.md) for the full command list.

### iOS — [`apps/ios`](apps/ios)

A SwiftUI iPhone app: timer, session stats, and settings. Open
`apps/ios/PomoiOS-App.xcodeproj` in Xcode.

### watchOS — [`apps/watch`](apps/watch)

A standalone watchOS app plus an iOS companion: WatchConnectivity sync,
Siri / App Intents, multiple themes (Terminal, LCD), and a circular progress
ring. Open `apps/watch/PomoWatch/PomoWatch.xcodeproj` in Xcode.

### Landing — [`landing`](landing)

The marketing site at **[pomo.arach.dev](https://pomo.arach.dev)**, a Next.js
static export deployed to GitHub Pages. Uses **bun**.

```sh
cd landing
bun install
bun run dev      # local dev server
bun run build    # static export to landing/out
```

## Layout

```
apps/
  macos/   SwiftUI menu-bar HUD          (primary, active)
  cli/     @arach/pomo CLI + TUI
  ios/     SwiftUI iPhone app
  watch/   watchOS app + iOS companion
landing/   Next.js marketing site        (pomo.arach.dev)
```

## Versioning

Two release lines share this repo:

| Line | Tag format | Current | Ships |
| --- | --- | --- | --- |
| macOS app | `v*` | `v0.2.8` | `Pomo.dmg` via GitHub Releases |
| npm CLI | `cli-v*` | `cli-v0.3.6` (next) | `@arach/pomo` on npm |

Keep `apps/cli/package.json` in sync with the latest npm publish before cutting
the next `cli-v*` tag.

## License

[MIT](LICENSE)