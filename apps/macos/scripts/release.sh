#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

version=""
dry_run=false
allow_dirty=false

usage() {
  cat <<EOF
Usage: scripts/release.sh VERSION [--dry-run] [--allow-dirty]

Create and push the canonical v<version> tag that triggers the signed macOS DMG
release workflow.

Examples:
  scripts/release.sh 0.2.5
  scripts/release.sh 0.2.5 --dry-run

Checks:
  - VERSION must look like X.Y.Z
  - current branch must be main
  - HEAD must match origin/main
  - no tracked files may be dirty unless --allow-dirty is used
  - v<version> must not already exist locally or on origin
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=true
      shift
      ;;
    --allow-dirty)
      allow_dirty=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 64
      ;;
    *)
      if [[ -n "$version" ]]; then
        echo "Only one VERSION may be provided." >&2
        usage >&2
        exit 64
      fi
      version="$1"
      shift
      ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "VERSION is required." >&2
  usage >&2
  exit 64
fi

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must look like X.Y.Z, got: $version" >&2
  exit 64
fi

cd "$repo_root"

tag="v$version"
message="${POMO_RELEASE_TAG_MESSAGE:-Pomo $version}"
branch="$(git branch --show-current)"

if [[ "$branch" != "main" ]]; then
  echo "Release tags must be created from main; current branch is: $branch" >&2
  exit 1
fi

git fetch origin main --tags --quiet

head_sha="$(git rev-parse HEAD)"
origin_main_sha="$(git rev-parse origin/main)"
if [[ "$head_sha" != "$origin_main_sha" ]]; then
  echo "HEAD does not match origin/main." >&2
  echo "Run: git pull --ff-only origin main" >&2
  exit 1
fi

if [[ "$allow_dirty" != true ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Tracked files are dirty. Commit or stash them before releasing." >&2
    echo "Use --allow-dirty only when the tracked changes are unrelated to the release." >&2
    exit 1
  fi
fi

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Local tag already exists: $tag" >&2
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  echo "Remote tag already exists: $tag" >&2
  exit 1
fi

echo "Release tag: $tag"
echo "Commit: $head_sha"
echo "Message: $message"

if [[ "$dry_run" == true ]]; then
  echo "Dry run only; no tag was created or pushed."
  exit 0
fi

git tag -a "$tag" -m "$message"
git push origin "$tag"

echo "Pushed $tag. Watch the release workflow:"
echo "  gh run list --repo arach/pomo --workflow \"Release App macOS\" --limit 1"
