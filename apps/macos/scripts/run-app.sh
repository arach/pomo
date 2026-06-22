#!/usr/bin/env bash
set -euo pipefail

# Builds the native Pomo macOS app bundle and launches it.
#
# Pomo consumes the local HudsonKit ("Hudson") package. HUDSONKIT_WITH_VOICE=0
# keeps Hudson's manifest from pulling its optional vox/Termini git dependencies,
# so the build is fully offline.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_name="Pomo"
bundle_id="dev.pomo.hud"
app_path="${POMO_APP_PATH:-$repo_root/dist/$app_name.app}"
configuration=release
restart=false

usage() {
  cat <<EOF
Usage: run-app.sh [--debug] [--restart] [--no-open]

  --debug     Build the debug configuration (faster iteration)
  --restart   Quit a running Pomo before launching
  --no-open   Build + bundle only; don't launch
EOF
}

open_app=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) configuration=debug; shift ;;
    --restart) restart=true; shift ;;
    --no-open) open_app=false; shift ;;
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
bin_path="$(swift build ${build_args[@]+"${build_args[@]}"} --show-bin-path)/Pomo"

echo "▸ Assembling $app_name.app…"
rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path" "$app_path/Contents/MacOS/$app_name"
chmod +x "$app_path/Contents/MacOS/$app_name"

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
  <string>$app_name</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
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

# Strip the quarantine flag so the unsigned, locally-built bundle launches
# without a Gatekeeper prompt — handy for devs who can't code-sign.
xattr -dr com.apple.quarantine "$app_path" 2>/dev/null || true

echo "▸ Built $app_path"

if [[ "$restart" == true ]]; then
  killall "$app_name" 2>/dev/null || true
  sleep 0.3
fi

if [[ "$open_app" == true ]]; then
  echo "▸ Launching…"
  open "$app_path"
fi
