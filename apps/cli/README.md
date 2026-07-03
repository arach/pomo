# @arach/pomo

**Website:** [pomo.arach.dev](https://pomo.arach.dev) · **npm:**
[@arach/pomo](https://www.npmjs.com/package/@arach/pomo) · **GitHub:**
[arach/pomo](https://github.com/arach/pomo)

Control the Pomo macOS timer from your shell
or an agent — and install it if it's not there yet. A zero-dependency wrapper
over Pomo's `pomo://` URL scheme and the JSON state file it writes on every
tick: start, pause, or skip sessions, set your intent, drive audio and YouTube
playback, and read timer state back as JSON. Or run the live ANSI terminal UI
(13 templates, 12 themes) next to the floating watch-face HUD that sits on
screen while you work.

<p align="center">
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-tui.png" alt="Pomo terminal UI" width="720" />
</p>

### macOS HUD

<p align="center">
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-hud-popover.png" alt="Pomo menu bar popover" width="240" />
  &nbsp;&nbsp;
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-hud-watch.png" alt="Watch face" width="240" />
  &nbsp;&nbsp;
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-hud-lcd.png" alt="LCD face" width="240" />
</p>

### Terminal UI

<p align="center">
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-tui-flapboard.png" alt="Split-flap · Chronograph" width="340" />
  &nbsp;
  <img src="https://unpkg.com/@arach/pomo/docs/pomo-tui-marquee.png" alt="Marquee · Receipt" width="340" />
</p>

## Use it

No install needed — run it with `npx`:

```sh
npx @arach/pomo install     # download & install the latest Pomo.app
npx @arach/pomo start       # start a focus session
npx @arach/pomo             # live terminal UI
```

Or put it on your PATH:

```sh
npm install -g @arach/pomo
pomo
```

**13 layout templates** (`T` to cycle) and **12 color themes** (`t` to cycle),
saved between sessions.

| Key | Action |
| --- | --- |
| `space` | start / pause timer |
| `a` | play / pause track |
| `i` | edit intent |
| `T` | cycle **template** (layout) |
| `t` | cycle **theme** (colors) |
| `n` | skip session |
| `h` | toggle HUD |
| `4` | stats panel |
| `?` | help |
| `q` / `esc` | quit / close overlay |

Preview a look without changing your saved prefs:

```sh
POMO_TUI_TEMPLATE=lcd POMO_TUI_THEME=amber npx @arach/pomo tui
POMO_TUI_TEMPLATE=watch POMO_TUI_THEME=neon npx @arach/pomo tui
```

## Commands

```
Timer      tui · status [--json] · start · pause · toggle · reset · skip
           session <focus|short|long> · duration <minutes>
Intent     intent <text…> · intent clear
Audio      audio <url> · audio <play|pause|stop|next|prev>
           audio session <focus|break|long> <favorite#|url|clear> · volume <0-100>
Video      video <show|hide|toggle|page|player|browser>
Favorites  fav · fav add <url> [title…] · fav rename <n> <title…>
           fav url <n> <url> · fav move <from> <to>
           fav set <json-file|json|-> · fav play <n> · fav remove <n> · fav clear
Window     show · hide · hud · menu · face <name> · settings · stats
Login      login · login import [--browser b] [--profile p] · login profiles
           login account <n> · logout
App        install [--dry-run] [--open] · quit
```

Run `pomo help` for the full list.

### Examples

```sh
pomo intent "Writing the launch post"
pomo audio "https://youtube.com/watch?v=jfKfPfyJRdk"
pomo audio session focus 1
pomo fav play 1
pomo status --json | jq .remainingSeconds
```

### `install`

Finds the newest GitHub release carrying a `.dmg`, downloads it, mounts it,
copies `Pomo.app` into `/Applications`, clears the download quarantine, and
unmounts. `--dry-run` prints what it would do; `--open` launches the app afterward.

> **TUI works on any platform.** Commands that drive the timer (`start`, `stop`,
> `install`, etc.) require macOS + the Pomo app.

## How it works

- **Commands** → `open "pomo://<verb>"` (fire-and-forget).
- **TUI / `status`** → reads `~/Library/Application Support/Pomo/state.json`.
