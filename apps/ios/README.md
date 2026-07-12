# Pomo — iPhone

A native SwiftUI focus timer that brings Pomo’s desktop faces to iPhone:
intention-led sessions, seven timer faces, a face-only focus mode, Live
Activities, drift-resistant timing, activity charts, and private on-device
history.

## Build

Open `PomoiOS-App.xcodeproj` in Xcode and run the `PomoiOS-App` scheme on an
iPhone simulator or device. The first App Store candidate targets iPhone in
portrait orientation and requires iOS 18.5 or later.

Command-line simulator build:

```sh
mkdir -p "$HOME/Library/Caches/codex-builds"
DERIVED_DATA_DIR="$(mktemp -d "$HOME/Library/Caches/codex-builds/deriveddata.XXXXXXXX")"
xcodebuild \
  -project PomoiOS-App.xcodeproj \
  -scheme PomoiOS-App \
  -sdk iphonesimulator \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## App Store package

Draft listing copy, privacy answers, review notes, screenshot captions, and the
release checklist live in [`AppStore/metadata.md`](AppStore/metadata.md).

The target includes:

- a 1024 × 1024 opaque App Store icon adapted from the macOS Pomo icon;
- a WidgetKit extension for Lock Screen and Dynamic Island Live Activities;
- `PrivacyInfo.xcprivacy`, declaring local `UserDefaults` use with `CA92.1`;
- the production bundle identifier `dev.arach.pomo`;
- export-compliance and Productivity category Info.plist values.

For deterministic marketing captures, Debug builds accept:

```text
-appStorePreview
-previewTab timer|stats|settings
```

`-appStorePreview` uses in-memory sample activity and does not write that sample
data into the shipping app’s history.

> Part of the [Pomo monorepo](../../README.md). The actively-developed desktop
> implementation remains under [`apps/macos`](../macos).
