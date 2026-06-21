#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
app_path="${1:-${POMO_APP_PATH:-$repo_root/dist/Pomo.app}}"

usage() {
  cat <<EOF
Usage: dequarantine-app.sh [path-to-Pomo.app]

Clears macOS Gatekeeper's quarantine flag from an unsigned Pomo.app bundle.
Defaults to: $repo_root/dist/Pomo.app
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if ! command -v xattr >/dev/null 2>&1; then
  echo "xattr is required on macOS." >&2
  exit 69
fi

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 66
fi

if [[ ! -f "$app_path/Contents/Info.plist" ]]; then
  echo "That does not look like a macOS .app bundle: $app_path" >&2
  exit 65
fi

echo "▸ Clearing quarantine flag from $app_path"
if ! xattr -d -r com.apple.quarantine "$app_path"; then
  echo "Could not clear quarantine. If this app is owned by another user, try:" >&2
  printf '  sudo xattr -d -r com.apple.quarantine %q\n' "$app_path" >&2
  exit 1
fi
echo "✓ Quarantine cleared, or no quarantine flag was present."

printf '  Launch with: open %q\n' "$app_path"
