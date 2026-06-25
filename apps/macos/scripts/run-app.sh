#!/usr/bin/env bash
set -euo pipefail

# Builds the native Pomo macOS app bundle and launches it.
#
# Pomo consumes the local HudsonKit ("Hudson") package. HUDSONKIT_WITH_VOICE=0
# keeps Hudson's manifest from pulling its optional vox/Termini git dependencies,
# so the build is fully offline.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="Pomo"
# Local dev builds get a `.dev` bundle id + label so they don't collide with an
# installed Pomo — LaunchServices would otherwise dedupe launches (and `pomo://`
# routing) to the wrong copy. DMG/release builds (build-dmg.sh) override these
# back to the canonical id, so signing / notarization / installs are unaffected.
bundle_id="${POMO_BUNDLE_ID:-dev.pomo.hud.dev}"
display_name="${POMO_DISPLAY_NAME:-Pomo Dev}"
app_path="${POMO_APP_PATH:-$repo_root/dist/$app_name.app}"
version="${POMO_VERSION:-0.1.0}"
configuration=release
restart=false
sign_identity=""

pomo_process_lines() {
  ps -axo pid=,command= | awk '/\/Pomo\.app\/Contents\/MacOS\/Pomo$/'
}

parse_process_line() {
  local line="$1"
  line="${line#"${line%%[![:space:]]*}"}"
  local pid="${line%%[[:space:]]*}"
  local command="${line#"$pid"}"
  command="${command#"${command%%[![:space:]]*}"}"
  printf '%s\t%s\n' "$pid" "$command"
}

stop_pomo_processes() {
  local line parsed pid
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    parsed="$(parse_process_line "$line")"
    pid="${parsed%%$'\t'*}"
    [[ -n "$pid" ]] || continue
    kill "$pid" 2>/dev/null || true
  done < <(pomo_process_lines)
}

wait_for_pomo_processes_to_exit() {
  local attempt
  for attempt in {1..20}; do
    if [[ -z "$(pomo_process_lines)" ]]; then
      return 0
    fi
    sleep 0.1
  done
}

stop_other_pomo_processes() {
  local expected_executable="$1"
  local line parsed pid command
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    parsed="$(parse_process_line "$line")"
    pid="${parsed%%$'\t'*}"
    command="${parsed#*$'\t'}"
    [[ -n "$pid" && "$command" != "$expected_executable" ]] || continue
    echo "  Stopping duplicate Pomo at $command"
    kill "$pid" 2>/dev/null || true
  done < <(pomo_process_lines)
}

copy_framework() {
  local framework_name="$1"
  local search_root="$2"
  local destination="$3"
  local source

  source="$(find "$search_root" -maxdepth 8 -path "*/$framework_name" -type d 2>/dev/null | head -n 1 || true)"
  if [[ -z "$source" ]]; then
    return 1
  fi

  ditto "$source" "$destination/$framework_name"
  return 0
}

bundle_swiftpm_frameworks() {
  local executable="$1"
  local build_bin_dir="$2"
  local frameworks_dir="$app_path/Contents/Frameworks"
  local framework_names=()
  local framework_name

  while IFS= read -r framework_name; do
    framework_names+=("$framework_name")
  done < <(
    otool -L "$executable" |
      awk '/@rpath\/.*\.framework\// { split($1, parts, "/"); print parts[2] }' |
      sort -u
  )

  if (( ${#framework_names[@]} == 0 )); then
    return 0
  fi

  mkdir -p "$frameworks_dir"
  for framework_name in "${framework_names[@]}"; do
    if copy_framework "$framework_name" "$build_bin_dir" "$frameworks_dir"; then
      continue
    fi
    if copy_framework "$framework_name" "$repo_root/.build/artifacts" "$frameworks_dir"; then
      continue
    fi

    echo "Could not find required framework: $framework_name" >&2
    exit 1
  done

  if ! otool -l "$executable" | grep -q '@executable_path/../Frameworks'; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" "$executable"
  fi
}

usage() {
  cat <<EOF
Usage: run-app.sh [--debug] [--restart] [--no-open] [--sign IDENTITY]

  --debug     Build the debug configuration (faster iteration)
  --restart   Quit a running Pomo before launching
  --no-open   Build + bundle only; don't launch
  --sign IDENTITY  Code-sign the app bundle; use "-" for local ad-hoc signing
EOF
}

open_app=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) configuration=debug; shift ;;
    --restart) restart=true; shift ;;
    --no-open) open_app=false; shift ;;
    --sign)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        echo "--sign requires an identity, for example: --sign -" >&2
        usage
        exit 64
      fi
      sign_identity="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 64 ;;
  esac
done

cd "$repo_root"
export HUDSONKIT_WITH_VOICE=0

icon_icns="$repo_root/Resources/AppIcon.icns"
if [[ ! -f "$icon_icns" ]]; then
  echo "▸ Generating app icon…"
  swift "$repo_root/scripts/generate-app-icon.swift" || echo "  (icon generation failed, continuing without icon)"
fi

# Build the cookie helper (rookie) — optional; enables `login import`.
cookie_helper="$repo_root/tools/cookie-helper/target/release/pomo-cookies"
if command -v cargo >/dev/null 2>&1; then
  echo "▸ Building cookie helper (rookie)…"
  ( cd "$repo_root/tools/cookie-helper" && cargo build --release ) >/dev/null 2>&1 \
    || echo "  (cookie helper build failed; 'login import' will be unavailable)"
fi

echo "▸ Building Pomo ($configuration)…"
build_args=()
if [[ "$configuration" == "release" ]]; then
  build_args+=(-c release)
fi
swift build ${build_args[@]+"${build_args[@]}"} --product Pomo
build_bin_dir="$(swift build ${build_args[@]+"${build_args[@]}"} --show-bin-path)"
bin_path="$build_bin_dir/Pomo"

echo "▸ Assembling $app_name.app…"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path" "$app_path/Contents/MacOS/$app_name"
chmod +x "$app_path/Contents/MacOS/$app_name"
bundle_swiftpm_frameworks "$app_path/Contents/MacOS/$app_name" "$build_bin_dir"

# Bundle the HudsonKit frameworks next to the executable. The binary links them
# via @rpath (which includes Contents/MacOS), so without this the app aborts at
# launch with "Library not loaded: @rpath/HudsonUI.framework".
bin_dir="$(dirname "$bin_path")"
for fw in "$bin_dir"/*.framework; do
  [ -e "$fw" ] || continue
  ditto "$fw" "$app_path/Contents/MacOS/$(basename "$fw")"
done

if [[ -f "$icon_icns" ]]; then
  cp "$icon_icns" "$app_path/Contents/Resources/AppIcon.icns"
fi

if [[ -f "$cookie_helper" ]]; then
  cp "$cookie_helper" "$app_path/Contents/MacOS/pomo-cookies"
  chmod +x "$app_path/Contents/MacOS/pomo-cookies"
fi

cat > "$app_path/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$app_name</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$bundle_id</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$display_name</string>
  <key>CFBundleDisplayName</key>
  <string>$display_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$version</string>
  <key>CFBundleVersion</key>
  <string>$version</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>$bundle_id</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>pomo</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

if [[ -n "$sign_identity" ]]; then
  if ! command -v codesign >/dev/null 2>&1; then
    echo "codesign is required for --sign." >&2
    exit 69
  fi

  echo "▸ Signing $app_name.app…"
  codesign_args=(--force --deep --sign "$sign_identity")
  if [[ "$sign_identity" != "-" ]]; then
    codesign_args+=(--options runtime --timestamp)
  fi
  codesign "${codesign_args[@]}" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"
fi

# Strip the quarantine flag so the locally-built bundle launches without a
# Gatekeeper prompt. Signed release builds still need notarization for sharing.
"$repo_root/scripts/dequarantine-app.sh" "$app_path" >/dev/null 2>&1 || true

echo "▸ Built $app_path"
if [[ -n "$sign_identity" ]]; then
  echo "  Signed with: $sign_identity"
  echo "  For distribution, notarize and staple the app before publishing."
else
  echo "  Unsigned build. If macOS blocks it after moving or copying, run:"
  printf '  scripts/dequarantine-app.sh %q\n' "$app_path"
  echo "  Use the path to the copy you actually open, such as /Applications/Pomo.app."
fi

if [[ "$restart" == true ]]; then
  stop_pomo_processes
  wait_for_pomo_processes_to_exit
fi

if [[ "$open_app" == true ]]; then
  echo "▸ Launching…"
  open "$app_path"
  if [[ "$restart" == true ]]; then
    sleep 0.7
    stop_other_pomo_processes "$app_path/Contents/MacOS/$app_name"
  fi
fi
