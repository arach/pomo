#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS="$ROOT/docs"
RENDERER="$ROOT/scripts/render-ansi-png.swift"
RENDER_BIN="$ROOT/scripts/render-ansi-png-bin"
POMO="$ROOT/bin/pomo.js"

mkdir -p "$DOCS"
if [[ ! -x "$RENDER_BIN" ]]; then
  swiftc -O -o "$RENDER_BIN" "$RENDERER"
fi

render() {
  local template="$1"
  local theme="$2"
  local out="$3"
  local cols="${4:-100}"
  local rows="${5:-40}"
  node "$POMO" screenshot --out "$out" --template "$template" --theme "$theme" --cols "$cols" --rows "$rows"
}

render ticket amber "$DOCS/pomo-tui-ticket.png" 88 36
render sheet blueprint "$DOCS/pomo-tui-sheet.png" 100 40
render lcd amber "$DOCS/pomo-tui-lcd.png" 72 30
render watch chronograph "$DOCS/pomo-tui-watch.png" 80 34
render studio ember "$DOCS/pomo-tui-studio.png" 92 36

# Hero image for npm README — sheet layout reads closest to the product HUD.
cp "$DOCS/pomo-tui-sheet.png" "$DOCS/pomo-tui.png"

echo "wrote CLI docs screenshots to $DOCS"