# Pomo Amp HTML Skin SDK

Pomo Amp skins are plain HTML/CSS/JavaScript bundles. A skin can draw any interface
it wants, but the native bridge is intentionally small: the only host object is
`window.yamp`, and the only native command entry point is `yamp.action(name)`.

## Install Location

During development, put each skin in its own folder:

```text
~/Library/Application Support/Pomo Amp/Skins/<skin-id>/
  skin.json
  index.html
  assets...
```

Pomo Amp creates a `hello-pomo-amp` example skin there on first launch.

## Manifest

Every skin folder needs a `skin.json` file:

```json
{
  "id": "my-skin",
  "name": "My Skin",
  "version": "1.0.0",
  "engine": "html@1",
  "entry": "index.html",
  "author": "You",
  "size": { "width": 386, "height": 198 }
}
```

Only `engine: "html@1"` is loaded today. `entry` must point to an HTML file
inside the skin folder.

## Host API

Pomo Amp injects this object before the page runs:

```js
yamp.version              // "html@1"
yamp.ready()              // asks the host to send current state
yamp.onState(callback)    // subscribes to state snapshots
yamp.onViz(callback)      // subscribes to native visualizer frames
yamp.onScope(callback)    // alias for onViz(callback)
yamp.onDrag(callback)     // reserved for host drag events; not emitted by default
yamp.action(name)         // asks the host to perform an allowed action
```

State snapshots currently look like:

```json
{
  "isPlaying": false,
  "title": "Paste a YouTube URL",
  "url": "",
  "thumbnailURL": "",
  "source": "no source",
  "videoOpen": false,
  "videoExpanded": false,
  "isBig": false,
  "face": "hello-pomo-amp",
  "shortcuts": [
    { "key": "Space", "label": "Play / pause" }
  ]
}
```

Visualizer frames are produced by Swift from the player media clock plus any
available live audio scope data. The webface should render these values, not run
its own independent timing loop:

```json
{
  "version": 1,
  "frame": 12345,
  "source": "webAudio",
  "sourceError": null,
  "latencyMs": 38,
  "hostTime": 84231.42,
  "mediaTime": 81.37,
  "duration": 3600,
  "progress": 0.0226,
  "playbackRate": 1,
  "isPlaying": true,
  "bpm": 0,
  "beatIndex": 0,
  "beatPhase": 1,
  "barIndex": 0,
  "barPhase": 1,
  "drop": 0.61,
  "rms": 0.48,
  "rmsDb": -6.4,
  "peak": 0.82,
  "peakDb": -1.7,
  "crestDb": 4.7,
  "transient": 0.24,
  "low": 0.64,
  "mid": 0.42,
  "high": 0.28,
  "sub": 0.42,
  "bass": 0.68,
  "lowMid": 0.45,
  "presence": 0.31,
  "brilliance": 0.18,
  "centroidHz": 1420,
  "bandwidthHz": 2100,
  "brightness": 0.56,
  "rolloff85Hz": 6200,
  "tonality": 0.72,
  "flux": 0.08,
  "bassFlux": 0.13,
  "onsetScore": 1.4,
  "onsetPulse": 0.92,
  "onset": true,
  "bands": [0.2, 0.4, 0.7],
  "waveform": [-0.2, 0.1, 0.4]
}
```

`hostTime` is a monotonic native clock in seconds. `mediaTime` is extrapolated
from YouTube's media element timing samples, so faces can do subsecond synced
drops and bounces without querying the YouTube page.

`source` tells you where the scope data came from:

- `webAudio`: `bands`, `waveform`, `rms`, `peak`, `low`, `mid`, `high`, and
  `drop` are derived from a live Web Audio analyser attached to the YouTube media
  element as it plays.
- `screenCapture`: Web Audio was unavailable or silent, so the native host is
  deriving scope data from ScreenCaptureKit audio for the app's playing WebKit
  content.
- `none`: no audio scope is available yet.
- `stale`: the last analyser frame is too old to trust.
- `blocked`: WebKit/YouTube blocked analysis or the analyser returned silent
  data while playback was active. Check `sourceError`.

Pomo Amp does not synthesize fake beat, BPM, or spectrum data. If `source` is not
`webAudio` or `screenCapture`, skins should render a quiet visualizer state.
`beatIndex`, `beatPhase`, `barIndex`, and `barPhase` are reserved for future
native beat detection and are not meaningful yet.

Skins can use `thumbnailURL` as passive artwork for YouTube tracks. The reference
skin renders it as a blurred video-art layer behind the visualizer. `brightness`,
`rolloff85Hz`, and `tonality` are spectral color/texture hints derived from the
current band shape; `flux`, `bassFlux`, `onsetScore`, `onsetPulse`, and `onset`
are onset hints, not full BPM or beat-grid tracking.

Drag callbacks, if a future host surface emits them, receive:

```json
{
  "active": true,
  "phase": "move",
  "x": 24,
  "y": 18,
  "width": 386,
  "height": 198,
  "screenX": 512,
  "screenY": 740,
  "dx": 8,
  "dy": -2,
  "totalDx": 64,
  "totalDy": 12,
  "velocityX": 480,
  "velocityY": -120,
  "speed": 495,
  "directionX": 0.97,
  "directionY": -0.24,
  "angleDegrees": -14
}
```

`phase` is `start`, `move`, or `end`. `x/y` are the original grab point relative
to the skin viewport, measured from the top left. Movement fields are in screen
points; positive `dx` moves right, and positive `dy` moves the window up. Speed is
points per second.

Supported actions:

| Action | Effect |
| --- | --- |
| `playPause` | Toggle playback |
| `previousTrack` | Play the previous item in Pomo Amp's saved playlist |
| `nextTrack` | Play the next item in Pomo Amp's saved playlist |
| `previousSection` | Jump to the previous YouTube timestamp section |
| `nextSection` | Jump to the next YouTube timestamp section |
| `toggleVideo` | Show or hide the video drawer |
| `expandVideo` | Show the video drawer |
| `minimizeVideo` | Hide the video drawer |
| `showVideoPage` | Show the full YouTube page in the video drawer |
| `showVideoPlayer` | Show the compact player view in the video drawer |
| `pasteURL` | Paste a YouTube URL from the clipboard and play it |
| `enableAudioScope` | Ask for macOS screen/system audio permission for the visualizer |
| `showShortcuts` | Show Pomo Amp's keyboard shortcut overlay |
| `minimizeWindow` | Hide the Pomo Amp window |
| `toggleBig` | Toggle between compact and big Pomo Amp sizes |
| `enterBig` | Switch to the big Pomo Amp size |
| `exitBig` | Switch to the compact Pomo Amp size |
| `hide` | Hide the Pomo Amp window |
| `nextNativeFace` | Cycle the fallback native face setting |

Unknown actions are ignored.

## Example

```html
<button data-action="playPause">Play</button>

<script>
  document.querySelector("[data-action]").addEventListener("click", event => {
    yamp.action(event.currentTarget.dataset.action);
  });

  yamp.onState(state => {
    document.title = state.title;
  });

  yamp.ready();
</script>
```

## Reference skin

Pomo Amp ships with `hello-pomo-amp` ("Pomo Amp Studio") as the reference
implementation, and it is the face Pomo Amp shows by default. It is a good
starting point for a custom skin and demonstrates the intended patterns:

- It treats the title as the hero and keeps a compact transport + utility row.
- It reacts to `isPlaying` by toggling a `playing` class on `<body>`.
- It renders its meter and status LED from `yamp.onViz(...)`, using live
  live scope band data when available and a quiet state otherwise.
- It layers a waveform, progress rail, band meter, beat glow, and drop pulse from
  the same native visualizer frame.
- It maps `videoOpen` / `videoExpanded` onto the `VID` and `PAGE` controls,
  swapping the `PAGE` button between `showVideoPage` and `showVideoPlayer`.

Build your own skin by copying that folder under a new `<skin-id>` and editing the
HTML/CSS — Pomo Amp loads the first installed skin alphabetically by name.

## Boundaries

The skin WebView uses non-persistent website data, loads from the installed skin
folder, and blocks main-frame navigation outside that folder. Playback, YouTube
control, timestamp navigation, settings, and the video drawer remain native host
responsibilities.

The native host supplies a small visible drag grip outside the webface. Skins
should treat their own document as a normal clickable control surface.

In debug builds, Pomo Amp also exposes a native "Viz Data" drawer from the chrome
row/context menu. It slides out beside the face and shows the current
`PomoAmpVizData` payload, including timing, phase, bands, waveform, and energy
fields. This viewer is for skin development only and is not part of the release
player surface.
