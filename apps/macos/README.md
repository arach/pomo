# Pomo — macOS

A native macOS **HUD Pomodoro timer**. Lives in the menu bar, summons a frosted,
borderless floating panel with a global hotkey, and renders the countdown
through swappable **watchfaces**. Built in SwiftUI on top of HudsonKit for design
tokens and window chrome. The primary Pomo implementation.

## Highlights

- **Menu-bar app** (no dock icon) showing the live countdown.
  - **Left-click** → a frosted control popover (transport, session, watchface,
    sound, background audio, and a "Show HUD" button).
  - **Right-click** → a compact native menu to change config from a list
    (session · duration · watchface · sound).
- **Hotkey-summoned HUD** — `⌃⌥⇧⌘P` fades a borderless, always-on-top panel in/out.
  It floats over every Space, is draggable from anywhere, and frosts the desktop
  behind it via a tunable **backdrop blur**.
- **Watchfaces** — `Minimal`, `Terminal`, `Neon`, `Retro Digital`, `Rolodex`,
  `Chronograph`, and `Blueprint` (an engineering-drawing face styled after the
  Hudson landing page). Cycle with `T`.
- **Classic Pomodoro flow** — focus → short break → long break (every Nth),
  drift-free timing, completion chime synthesized at runtime.
- **Background audio** — paste a YouTube/stream link to play lo-fi while you work.
- **Settings** — durations, watchface, opacity, background blur, sound, hotkey.
- **`pomo://` URL scheme** for agent control (start/pause/skip/face/audio/…) with
  a JSON state file written back for status reads.

## Quick commands

```sh
cd apps/macos
scripts/run-app.sh
```

That builds a release binary, assembles `dist/Pomo.app`, and launches it.

Useful variants:

```sh
scripts/run-app.sh --debug    # faster local build
scripts/run-app.sh --restart  # quit a running copy before launching
scripts/run-app.sh --no-open  # build dist/Pomo.app without launching
scripts/run-app.sh --no-open --sign -  # local ad-hoc signature
scripts/build-dmg.sh --local  # build a local smoke-test dist/Pomo.dmg
open dist/Pomo.app            # launch the built app later
```

Build to a custom app path:

```sh
POMO_APP_PATH="/Applications/Pomo.app" scripts/run-app.sh --no-open
```

### Unsigned app blocked by macOS

Pomo isn't code-signed or notarized, so a copy you download or move into
`/Applications` gets quarantined by Gatekeeper ("…can't be opened because Apple
cannot check it for malicious software", or "`Pomo.app` is damaged and can't be
opened").

If you trust the build and have a source checkout, clear the quarantine flag on
the app bundle you are actually opening:

```sh
scripts/dequarantine-app.sh /Applications/Pomo.app
```

For the default local build path:

```sh
scripts/dequarantine-app.sh dist/Pomo.app
```

The helper validates that the path looks like a `.app` bundle, removes only the
`com.apple.quarantine` attribute recursively, and prints the `open` command to
launch it.

If you only downloaded `Pomo.app` and do not have this repo, use the raw command:

```sh
xattr -d -r com.apple.quarantine /Applications/Pomo.app
```

`scripts/run-app.sh` also runs this helper against the bundle it builds, so local
builds should launch without the prompt.

### Signed builds

For local development, ad-hoc signing is enough to give the bundle a code
signature on your Mac:

```sh
scripts/run-app.sh --no-open --sign -
codesign --verify --deep --strict --verbose=2 dist/Pomo.app
open dist/Pomo.app
```

To package the app as a drag-to-Applications DMG for local testing:

```sh
scripts/build-dmg.sh --local
open dist/Pomo.dmg
```

That DMG is convenient for local testing, but it is still not a publicly trusted
download unless you sign and notarize it.

For a build you plan to share, use an Apple Developer ID Application certificate
and notarize the DMG. Replace the identity and notary profile names with your own:

```sh
POMO_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
POMO_NOTARY_PROFILE="notarytool-profile" \
  scripts/build-dmg.sh
```

Attach the notarized DMG to a GitHub Release:

```sh
gh release upload "$(gh release view --json tagName -q .tagName)" dist/Pomo.dmg --clobber
```

### GitHub release workflow

The **Release App macOS** workflow builds, signs, notarizes, staples, verifies,
and uploads the public DMG. It publishes to GitHub Releases only when run from
an `app-macos-v<version>` tag or when manually run with `publish=true`.

Release from a tag:

```sh
git tag -a app-macos-v0.2.2 -m "Pomo macOS 0.2.2"
git push origin app-macos-v0.2.2
```

Or run it manually:

```sh
gh workflow run release-app-macos.yml --ref master -f version=0.2.2 -f publish=true
```

The workflow creates or updates release `v<version>` with:

```text
Pomo.dmg
Pomo-<version>.dmg
```

The landing page downloads from:

```text
https://github.com/arach/pomo/releases/latest/download/Pomo.dmg
```

Configure these GitHub Actions secrets before relying on that artifact:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION_CERT_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `DEVELOPER_ID_APPLICATION_CERT_PASSWORD` | Password for the exported `.p12` |
| `KEYCHAIN_PASSWORD` | Throwaway CI keychain password |
| `APP_STORE_CONNECT_API_KEY_P8` | App Store Connect API key `.p8` contents |

Optional GitHub Actions variable:

| Variable | Value |
| --- | --- |
| `APP_STORE_CONNECT_KEY_ID` | App Store Connect API key ID. Can also be a secret. |
| `APP_STORE_CONNECT_ISSUER_ID` | App Store Connect issuer ID. Optional for individual API keys. Can also be a secret. |

Create `DEVELOPER_ID_APPLICATION_CERT_BASE64` from the exported certificate:

```sh
base64 < DeveloperIDApplication.p12 | tr -d '\n' | pbcopy
```

One-time GitHub setup:

```sh
gh secret set DEVELOPER_ID_APPLICATION_CERT_BASE64 --repo arach/pomo --env release
gh secret set DEVELOPER_ID_APPLICATION_CERT_PASSWORD --repo arach/pomo --env release
gh secret set KEYCHAIN_PASSWORD --repo arach/pomo --env release
gh secret set APP_STORE_CONNECT_API_KEY_P8 --repo arach/pomo --env release < AuthKey_KEYID.p8

gh variable set APP_STORE_CONNECT_KEY_ID --repo arach/pomo --env release --body KEYID
# Optional for individual API keys:
gh variable set APP_STORE_CONNECT_ISSUER_ID --repo arach/pomo --env release --body ISSUER_UUID
```

For a smoke test, run **Release App macOS** manually with `publish=false`. That
builds an unsigned workflow artifact and intentionally skips the GitHub release.

Signing alone is useful for local builds, but downloadable DMGs still need
notarization and stapling to avoid Gatekeeper warnings for other users.

**No private source needed.** HudsonKit (design tokens + window chrome) is
consumed as a public, prebuilt **binary** SwiftPM package —
[`hudsonkit-xcframework`](https://github.com/arach/hudsonkit-xcframework) — so a
clean clone builds standalone. The first build downloads the release XCFrameworks
(macOS `arm64` + `x86_64`); subsequent builds are cached.

## Keyboard shortcuts (while the HUD is focused)

| Key | Action |
| --- | --- |
| `⌃⌥⇧⌘P` | Summon / dismiss the HUD (global) |
| `Space` / `S` / `P` | Start / pause |
| `R` | Reset |
| `N` | Skip to next session |
| `C` | Cycle session type (when idle) |
| `T` | Cycle watchface |
| `1`–`9` | Quick-set duration (×5 min, when idle) |
| `↑` / `↓` | ±1 min (`⇧` for ±5, when idle) |
| `Esc` / `Q` | Hide the HUD |
| `⌘,` | Open Settings |

## Architecture

```
Sources/Pomo/
  PomoApp.swift            @main — accessory app, empty Settings scene
  AppDelegate.swift        wires models, menu bar, HUD, hotkey, audio, URL scheme
  Core/                    TimerModel, PomoSettings, SessionType, Favorite, TimeFormat
  Hotkey/                  Carbon global-hotkey wrapper
  HUD/                     HUDPanel, HUDController, HUDRootView, BackdropBlurView
  MenuBar/                 status item, control popover, config menu
  Watchfaces/              Minimal / Terminal / Neon / Retro / Rolodex / Chronograph / Blueprint
  Audio/                   completion chime + background-audio playback
  Control/                 pomo:// URL scheme + state read-back
  Settings/                HudsonUI-flavoured settings surface
```

Business logic lives in the Swift `Core` layer; HudsonKit supplies tokens
(`HudPalette`, `HudFont`, `HudSpacing`, …) and the behind-window vibrancy.
