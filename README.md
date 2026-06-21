# Pomo

A native macOS **HUD Pomodoro timer**. Lives in the menu bar, summons a frosted,
borderless floating panel with a global hotkey, and renders the countdown
through swappable **watchfaces**. Built in SwiftUI on top of HudsonKit for design
tokens and window chrome.

> **This is the primary implementation.** Pomo began as a Tauri (web + Rust) app;
> the native Swift rewrite is now the main codebase. The original Tauri
> implementation is preserved, unchanged, under [`legacy/`](legacy/) (and on the
> `tauri` branch) — see [`legacy/README.md`](legacy/README.md).

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

## Run it

```sh
scripts/run-app.sh            # build (release), bundle Pomo.app, launch
scripts/run-app.sh --debug    # faster debug build
scripts/run-app.sh --restart  # quit a running instance first
```

**Requires** the sibling [HudsonKit](https://github.com/) package checked out at
`../hudson` (a local SwiftPM path dependency). The build sets
`HUDSONKIT_WITH_VOICE=0` so HudsonKit doesn't pull its optional `vox`/`Termini`
git dependencies — the build is fully offline.

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

## Legacy (Tauri)

The original Tauri/web implementation — the React + Rust app, landing page, and
the `PomoiOS-App` / `PomoWatch` companions — lives under [`legacy/`](legacy/).
It's frozen, not under active development, but kept for history and reference.
