# Pomo Amp Viz Lab

A self-contained, dependency-free web lab for designing the **Pomo Amp player face**
before committing anything to the native skin. Two layers:

- **Faces** — realistic player *compositions* (cover art / blur / translucency,
  title + source + video state, transport + progress, and always-reserved **bands +
  wave lanes**). This is "the starting face we might ship", judged in context.
- **Treatments** — the inner audio-reactive visual that a face frames (wave trace,
  bandprint EQ, spectrogram, groove rail, headroom, …). Treatments are deliberately
  *not* the whole face.

Motion is **calmed at the composition level** (a Gentle frame smoother), so the same
treatments read like a music player here and like a demo reel in the raw studio view.
Nothing is wired into the app — no native files were touched (native sources were read
for context only).

## Open it

```bash
open apps/macos/devtools/pomo-amp-viz-lab/index.html        # double-click also works (file://)
# strict file:// browser? serve it:
cd apps/macos/devtools/pomo-amp-viz-lab && python3 -m http.server 8777   # → http://localhost:8777
```

Plain HTML/CSS/vanilla JS, no build step — Codex can read the seven source files directly.
Deep-link a curated combo with `#preset=<id>` (e.g. `index.html#preset=console-spectro`),
a face with `#face=<id>` (or `#face=<id>/<treatment>`), or a treatment with `#<treatment-id>`.

## Faces (the new focus)

Pick a face in the **FACE** panel; pick its inner visual in **TREATMENT**. Every face
shows title/source, **video state** (Audio / Player / Page), a cover-art thumbnail with
blur/translucency, transport + progress, and **reserved BANDS + WAVE lanes** — even when
the main treatment is tonal, headroom, groove, or timbre analysis. The reserved lanes are the hook the
sound-engineering / music-science lanes plug their future treatments into.

| Face | `#face=` | Composition | Best for |
|---|---|---|---|
| **Now Playing** | `nowplaying` | Treatment is a dim, screen-blended backdrop behind a glass now-playing card; reserved bands+wave strip below | **Starting face to ship** — player first, visualizer second |
| **Module Stack** | `modules` | Hard-edged stacked panels, tiny state rails, boxed art, and a visualizer bay | Winamp-inspired presentation without literal retro cosplay |
| **Scope Bay** | `scopebay` | Boxed scope panes with sober readouts, BANDS, WAVE, and a compact transport footer | Pro audio / video-tool discipline; measurement first |
| **Ambient Glass** | `ambient` | Treatment fills the deck (calm, dimmed) over a color-washed cover; frosted-glass control bar floats transport + lanes | Showcasing translucency / blur feel |
| **Studio Console** | `studio` | Treatment is one contained module beside first-class **BANDS + WAVE panels** with guides | The slot for music-science treatments; metering up front |
| **Cinema** | `cinema` | 16:9 video stage reflecting video state; treatment as a slim **scrubber lane**; reserved bands mini-lane | Video-forward sources; title/source overlaid |

**Controls added for faces:** `Compose in face` (toggle back to the raw studio view),
`Motion: Calm / Lively`, a `Now playing` track picker (mock titles/sources/art, some with
video), and `Audio / Player / Page` to exercise video state. Transport buttons inside a
face are live (play/pause, prev/next track, cycle video).

### Presets (curated face + treatment combos)

The **PRESET** panel cycles strong face+treatment pairings so you don't have to pick both
grids by hand: ◂ / ▸ buttons, a dropdown, or the `[` / `]` keys. Selecting a preset sets
the face *and* the treatment (and turns compose on); the FACE/TREATMENT grids stay live for
manual mixing, which shows as **Custom**. Deep-link any preset with `#preset=<id>`. The
curated list lives in `js/presets.js`; see `TREATMENT_SPEC.md` § Presets. Initial set:

| `#preset=` | Combo |
|---|---|
| `ship` | Now Playing + Wave Trace |
| `console-spectro` | Studio Console + Spectrogram |
| `scope-headroom` | Scope Bay + Headroom |
| `module-bandprint` | Module Stack + Bandprint EQ |
| `ambient-spectro` | Ambient Glass + Spectrogram |
| `ambient-timbre` | Ambient Glass + Timbre Map |
| `cinema-groove` | Cinema + Groove Rail |
| `cinema-wave` | Cinema + Wave Trace |
| `console-foundation` | Studio Console + Bass Foundation |

### Judging against real audio

The face header makes live input obvious: enable **Live input** (mic) in the VIEW panel,
or **drag an audio file onto the HUD**. The source badge flips to an amber **● LIVE · MIC /
FILE** chip and the title becomes the mic/file name. Real audio runs through the *same*
metric pipeline as the simulator, so what you judge is what ships. (Mic needs permission;
the file path also routes to your speakers.)

## Treatments (inner visuals) and how portable each is

| Treatment | `#id` | What it is | Port effort |
|---|---|---|---|
| **Wave Trace** | `wave` | Waveform plus RMS envelope and onset ticks | trivial |
| **Bandprint EQ** | `bandprint` | 24-band spectral fingerprint with peak holds, centroid, and grouped labels | easy |
| **Spectrogram** | `spectro` | Scrolling time × frequency sonogram on a log-Hz axis, with centroid + rolloff traces | moderate |
| **Groove Rail** | `groove` | Onset history, transient density, drop pressure, and beat guides in sim mode | easy |
| **Headroom** | `headroom` | RMS, peak, crest, transient, and headroom/clipping risk | easy |
| **Timbre Map** | `timbre` | Slow trajectory through brightness/body/tonality space | easy |
| **Bass Foundation** | `foundation` | Sub/bass/low-mid foundation, mud pressure, and bass punch | easy |

The old decorative first-wave treatments (`particles`, `radial`, fake `vector`, and
`bloom`) were removed. A second pass then replaced the redundant `tilt` with `spectro`
(see `TREATMENT_SPEC.md` § Second Pass). The current set favors musical questions:
shape, spectrum now, spectral evolution over time, groove, headroom, timbre movement,
and low-end support.

## Presentation research

The current direction is summarized in `DESIGN_NOTES.md`: less rounded dashboard, more
compact instrument. The notes pull from Winamp skin density / sprite-state discipline,
professional audio metering, and video scope layouts.

## How a real skin would consume this

Native HTML-skin bridge (`PomoAmpSkinWebView.swift`):

```js
window.yamp.onViz(function (viz) { /* same fields the lab simulates */ });
```

- A **treatment** `draw(ctx, viz, { w, h, t, dt })` (`js/styles.js`) maps ~1:1 onto an
  `onViz` callback drawing into a canvas region.
- A **face** (`js/faces.js`) is the surrounding HTML/CSS composition + the reserved
  bands/wave lanes (`Lanes.bands` / `Lanes.wave`) + the `Gentle` calm smoother. Port a
  face by recreating its DOM in the skin and feeding `viz` (gentled) to the chosen treatment.

## Caveats

- **`bpm` / `beat*` / `bar*` are lab-only.** Pomo Amp emits `bpm: 0`, `beatPhase: 1` today
  (not computed yet). Faces/treatments meant to ship rely on `onsetPulse` / `rms` / `bands`,
  which are real.
- The synthetic signal is a *plausible model*, not a spectral copy of any track — use
  **Live input** for ground truth.
- Cover art, track titles, and video state are **mock context** for composition study; a
  real skin gets these from `PomoAmpSkinState` (title/source/thumbnailURL/videoOpen/…).
- `Calm` motion is a study aid (composition-level smoothing); the native feed is unchanged.
- `drop` can briefly exceed 1.0 (matches the Swift analyzer's partly-unclamped `max(...)`).

## Files

`index.html` · `css/lab.css` · `js/sim.js` (simulator + analyzer port) ·
`js/styles.js` (treatments) · `js/faces.js` (face compositions + Gentle + lanes) ·
`js/presets.js` (curated face + treatment combos) · `js/lab.js` (wiring) ·
`DESIGN_NOTES.md` (presentation research) ·
`TREATMENT_SPEC.md` (treatment pruning, replacement, and preset spec).

## Field reference

`version frame source sourceError latencyMs hostTime mediaTime duration progress
playbackRate isPlaying bpm beatIndex beatPhase barIndex barPhase drop rms rmsDb
peak peakDb crestDb transient low mid high sub bass lowMid presence brilliance
centroidHz bandwidthHz brightness rolloff85Hz tonality flux bassFlux onsetScore
onsetPulse onset bands[24] waveform[32]`
