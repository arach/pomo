#!/usr/bin/env bash
# Installs the `pomoctl` CLI by symlinking it into a PATH directory.
# Picks the first writable dir on PATH from a preference list.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pomoctl"
chmod +x "$src"

for dir in "$HOME/.local/bin" "/opt/homebrew/bin" "/usr/local/bin"; do
  if [[ -d "$dir" && -w "$dir" ]] || mkdir -p "$dir" 2>/dev/null; then
    ln -sf "$src" "$dir/pomoctl"
    echo "Installed: $dir/pomoctl -> $src"
    case ":$PATH:" in
      *":$dir:"*) echo "($dir is on your PATH — run 'hash -r' or open a new shell)";;
      *) echo "NOTE: add $dir to your PATH";;
    esac
    exit 0
  fi
done

echo "No writable PATH dir found; symlink $src manually." >&2
exit 1
