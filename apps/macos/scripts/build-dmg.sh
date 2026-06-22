#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

app_name="Pomo"
app_path="${POMO_APP_PATH:-$repo_root/dist/$app_name.app}"
dmg_path="${POMO_DMG_PATH:-$repo_root/dist/$app_name.dmg}"
volname="${POMO_DMG_VOLUME_NAME:-$app_name}"
version="${POMO_VERSION:-0.1.0}"
configuration=release
build_app=true
skip_sign="${POMO_SKIP_SIGN:-0}"
skip_notarize="${POMO_SKIP_NOTARIZE:-0}"
notary_profile="${POMO_NOTARY_PROFILE:-notarytool}"

default_sign_identity() {
  security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*\([A-F0-9]\{40\}\)[[:space:]]*"Developer ID Application:[^"]*".*/\1/p' \
    | head -n 1
}

sign_identity="${POMO_SIGN_IDENTITY:-$(default_sign_identity || true)}"

usage() {
  cat <<EOF
Usage: build-dmg.sh [--debug] [--local] [--no-build] [--app PATH] [--output PATH] [--volname NAME]

Builds, signs, notarizes, and packages Pomo.app into a drag-to-Applications DMG.

  --debug          Build the debug app before packaging
  --local          Build a local unsigned smoke DMG; skips signing and notarization
  --no-build       Package an existing app bundle
  --app PATH       App bundle to build/package (default: $app_path)
  --output PATH    DMG output path (default: $dmg_path)
  --volname NAME   Mounted volume name (default: $volname)

Environment:
  POMO_SIGN_IDENTITY    Developer ID Application identity; auto-detected if unset
  POMO_NOTARY_PROFILE   notarytool keychain profile (default: notarytool)
  POMO_VERSION          App bundle version (default: $version)
  POMO_SKIP_SIGN=1      Skip signing
  POMO_SKIP_NOTARIZE=1  Skip notarization
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      configuration=debug
      shift
      ;;
    --local)
      skip_sign=1
      skip_notarize=1
      shift
      ;;
    --no-build)
      build_app=false
      shift
      ;;
    --app)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        echo "--app requires a path." >&2
        usage
        exit 64
      fi
      app_path="$2"
      shift 2
      ;;
    --output)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        echo "--output requires a path." >&2
        usage
        exit 64
      fi
      dmg_path="$2"
      shift 2
      ;;
    --volname)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        echo "--volname requires a name." >&2
        usage
        exit 64
      fi
      volname="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 64
      ;;
  esac
done

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "hdiutil is required on macOS." >&2
  exit 69
fi

if [[ "$skip_sign" != "1" ]]; then
  if ! command -v codesign >/dev/null 2>&1; then
    echo "codesign is required for signed DMG builds." >&2
    exit 69
  fi

  if [[ -z "$sign_identity" ]]; then
    echo "Error: No Developer ID signing identity found." >&2
    echo "Set POMO_SIGN_IDENTITY or run with --local for an unsigned smoke DMG." >&2
    exit 1
  fi

  echo "Sign identity: $sign_identity"
fi

if [[ "$build_app" == true ]]; then
  run_args=(--no-open)
  if [[ "$configuration" == "debug" ]]; then
    run_args+=(--debug)
  fi
  if [[ "$skip_sign" != "1" ]]; then
    run_args+=(--sign "$sign_identity")
  fi

  # DMG/release builds carry the canonical bundle id + name (not the dev `.dev`
  # default) so signing, notarization, and installs match the shipped app.
  POMO_APP_PATH="$app_path" POMO_VERSION="$version" \
    POMO_BUNDLE_ID="${POMO_BUNDLE_ID:-dev.pomo.hud}" POMO_DISPLAY_NAME="${POMO_DISPLAY_NAME:-Pomo}" \
    "$repo_root/scripts/run-app.sh" "${run_args[@]}"
elif [[ "$skip_sign" != "1" ]]; then
  echo "Signing $app_path"
  codesign --force --deep --options runtime --timestamp --sign "$sign_identity" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"
fi

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found: $app_path" >&2
  exit 66
fi

if [[ ! -f "$app_path/Contents/Info.plist" ]]; then
  echo "That does not look like a macOS .app bundle: $app_path" >&2
  exit 65
fi

mkdir -p "$(dirname "$dmg_path")" "$repo_root/dist"
staging_dir="$(mktemp -d "$repo_root/dist/dmg-staging.XXXXXXXX")"
cleanup() {
  rm -rf "$staging_dir"
}
trap cleanup EXIT

echo "Packaging $dmg_path"
ditto "$app_path" "$staging_dir/$app_name.app"
ln -s /Applications "$staging_dir/Applications"

rm -f "$dmg_path"
hdiutil create -volname "$volname" -srcfolder "$staging_dir" -format UDZO -ov "$dmg_path"
hdiutil verify "$dmg_path"

if [[ "$skip_sign" != "1" ]]; then
  echo "Signing $dmg_path"
  codesign --force --sign "$sign_identity" "$dmg_path"
  codesign --verify --verbose=2 "$dmg_path"
fi

if [[ "$skip_sign" == "1" || "$skip_notarize" == "1" ]]; then
  echo "Skipping notarization."
else
  echo "Submitting $dmg_path for notarization"
  xcrun notarytool submit "$dmg_path" --keychain-profile "$notary_profile" --wait

  echo "Stapling notarization ticket"
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
fi

echo "Built DMG: $dmg_path"
if [[ "$skip_sign" != "1" ]]; then
  spctl --assess --type open --context context:primary-signature --verbose "$dmg_path" 2>&1 || true
else
  echo "Unsigned smoke DMG only. Do not ship this to users."
fi
