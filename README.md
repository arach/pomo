# Pomo

A Pomodoro timer, across platforms — a native **macOS** HUD app (the primary
implementation today), plus native **iOS** and **watchOS** companion apps. One
monorepo, organized by app.

## Apps

| App | Platform | Stack | Status |
| --- | --- | --- | --- |
| [`apps/macos`](apps/macos) | macOS | SwiftUI + HudsonKit | **Primary · active** |
| [`apps/ios`](apps/ios) | iOS | SwiftUI | Native companion |
| [`apps/watch`](apps/watch) | watchOS (+ iOS) | SwiftUI · WatchConnectivity · App Intents | Native companion |

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

### iOS — [`apps/ios`](apps/ios)

A SwiftUI iPhone app: timer, session stats, and settings. Open
`apps/ios/PomoiOS-App.xcodeproj` in Xcode.

### watchOS — [`apps/watch`](apps/watch)

A standalone watchOS app plus an iOS companion: WatchConnectivity sync,
Siri / App Intents, multiple themes (Terminal, LCD), and a circular progress
ring. Open `apps/watch/PomoWatch/PomoWatch.xcodeproj` in Xcode.

## Layout

```
apps/
  macos/   SwiftUI menu-bar HUD          (primary, active)
  ios/     SwiftUI iPhone app
  watch/   watchOS app + iOS companion
```

## License

[MIT](LICENSE)
