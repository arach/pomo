#!/usr/bin/env bash
# Installs the `pomo` CLI by symlinking the node entrypoint into a PATH dir.
# Picks the first writable dir on PATH from a preference list. (For a non-repo
# install, prefer: npm install -g @arach/pomo)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../cli/bin" && pwd)/pomo.js"
chmod +x "$src"

for dir in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  if [[ -d "$dir" && -w "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
    ln -sf "$src" "$dir/pomo"
    echo "Installed: $dir/pomo -> $src"
    case ":$PATH:" in
      *":$dir:"*) echo "($dir is on your PATH — run 'hash -r' or open a new shell)";;
      *) echo "NOTE: add $dir to your PATH";;
    esac
    exit 0
  fi
done

echo "No writable PATH dir found; symlink $src manually." >&2
exit 1
