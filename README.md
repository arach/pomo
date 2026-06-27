# Pomo

A Pomodoro timer, across platforms — a native **macOS** HUD app (the primary
implementation today), native **iOS** and **watchOS** apps, and the original
**Tauri** (web + Rust) app it grew out of. One monorepo, organized by app.

## Apps

| App | Platform | Stack | Status |
| --- | --- | --- | --- |
| [`apps/macos`](apps/macos) | macOS | SwiftUI + HudsonKit | **Primary · active** |
| [`apps/ios`](apps/ios) | iOS | SwiftUI | Native companion |
| [`apps/watch`](apps/watch) | watchOS (+ iOS) | SwiftUI · WatchConnectivity · App Intents | Native companion |
| [`apps/tauri`](apps/tauri) | Web / desktop | React + TypeScript + Tauri (Rust) | Original · archived |

### macOS — [`apps/macos`](apps/macos) · primary

Menu-bar HUD timer: a hotkey-summoned frosted panel, swappable **watchfaces**
(including the engineering-drawing **Blueprint** face), tunable **backdrop blur**,
background audio, and a `pomo://` URL scheme for agent control. The same package
also builds **Pomo Amp**, a small YouTube music-player sibling with custom HTML
skins.

```sh
cd apps/macos
scripts/run-app.sh            # build dist/Pomo.app and launch
scripts/run-app.sh --no-open  # build only
scripts/run-app.sh --debug    # faster local build
scripts/run-app.sh --amp --debug  # build and launch Pomo Amp
scripts/build-dmg.sh --local  # build a local smoke-test DMG with Pomo + Pomo Amp
```

No private checkout needed — HudsonKit is consumed as a public, prebuilt **binary**
package ([`hudsonkit-xcframework`](https://github.com/arach/hudsonkit-xcframework)),
fetched on first build. More build, signing, and Gatekeeper dequarantine commands
are in [`apps/macos/README.md`](apps/macos/README.md).

### iOS — [`apps/ios`](apps/ios)

A SwiftUI iPhone app: timer, session stats, and settings. Open
`apps/ios/PomoiOS-App.xcodeproj` in Xcode.

### watchOS — [`apps/watch`](apps/watch)

A standalone watchOS app plus an iOS companion: WatchConnectivity sync,
Siri / App Intents, multiple themes (Terminal, LCD), and a circular progress
ring. Open `apps/watch/PomoWatch/PomoWatch.xcodeproj` in Xcode.

### Tauri — [`apps/tauri`](apps/tauri) · original

The web + Rust app Pomo started as (v0.2.1), with its landing page and watchface
tooling. Kept for history and reference; no longer the focus.

```sh
cd apps/tauri && pnpm install && pnpm tauri:dev
```

## Layout

```
apps/
  macos/   SwiftUI menu-bar HUD          (primary, active)
  ios/     SwiftUI iPhone app
  watch/   watchOS app + iOS companion
  tauri/   React + Tauri desktop app     (original)
```

## License

[MIT](LICENSE)
