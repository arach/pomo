# Pomo Amp Viz Lab Treatment Spec

Goal: replace the first-wave standalone visualizer ideas with treatments that
are musically legible, useful inside a player face, and honest about the current
`PomoAmpVizData` fields.

## What To Remove

- Particle field: attractive, but it maps audio to decorative motion. It does
  not help a listener read the track.
- Radial pulse: strong silhouette, but too screensaver-like and too dependent
  on circular spectacle.
- Fake vectorscope: the current data is mono-ish `waveform[32]`, not stereo
  L/R data, so calling it a phase/vectorscope is misleading.
- Onset bloom: pleasant, but too little information. Its useful piece belongs
  inside a groove/onset lane.
- Old studio meters as the main "pro" idea: keep the headroom/crest value, but
  present it as a compact treatment rather than a generic meter demo.

## What To Keep Or Reframe

- Waveform: keep, but turn it into a waveform plus envelope/onset trace instead
  of a plain oscilloscope.
- Spectrum: keep, but turn it into a bandprint with peak holds, grouped labels,
  and centroid/tilt cues.

## New Treatment Set

1. Wave Trace (`wave`)
   - Shows waveform, RMS envelope, and onset ticks.
   - Useful answer: "What is the track's moment-to-moment shape?"

2. Bandprint EQ (`bandprint`)
   - Shows 24 bands, peak holds, grouped frequency labels, centroid marker, and
     tonal tilt.
   - Useful answer: "Where is the energy sitting spectrally?"

3. Tonal Tilt (`tilt`)
   - Shows sub, bass, low-mid, presence, and brilliance as a balance surface with
     dark-to-bright tilt and centroid horizon.
   - Useful answer: "Is this dark, boomy, forward, or bright?"

4. Groove Rail (`groove`)
   - Shows onset history, transient density, drop pressure, and beat/bar phase
     when synthetic beat metadata is available.
   - Useful answer: "How locked and busy is the groove?"

5. Headroom (`headroom`)
   - Shows RMS, peak, crest, transient, and headroom/clipping risk.
   - Useful answer: "How loud and punchy is this, and is there room left?"

6. Timbre Map (`timbre`)
   - Shows a slow trajectory through brightness/body/tonality space.
   - Useful answer: "How is the tone color moving over time?"

7. Bass Foundation (`foundation`)
   - Shows sub/bass/low-mid foundation, mud pressure, bass punch, and relation to
     presence/brilliance.
   - Useful answer: "Is the low end supporting the track or swallowing it?"

## Acceptance Criteria

- The treatment grid should contain seven treatments, in order: Wave Trace,
  Bandprint EQ, Spectrogram, Groove Rail, Headroom, Timbre Map, Bass Foundation.
  (See Second Pass below — Spectrogram replaces Tonal Tilt.)
- No treatment should claim stereo phase, key/chroma, or exact BPM analysis that
  the native feed does not provide.
- Every treatment should remain legible inside the 386x198 HUD and when embedded
  inside Module Stack, Scope Bay, Now Playing, and Studio Console faces.
- Motion should report level, onset, brightness, density, balance, or headroom;
  avoid free-floating decorative motion.
- Existing faces remain intact and only update their suggested treatment IDs.

## Second Pass (refinement)

The first-wave replacement set was strong but spectrally redundant: Bandprint EQ,
Tonal Tilt, and Bass Foundation all answered "where is the spectral energy?" from the
same grouped bands. Tonal Tilt was the most redundant — its dark/bright read is already
cued by Bandprint's tilt line and (now) the Spectrogram's centroid trace, and its
sub/bass/low-mid/presence groups duplicate Bass Foundation.

Change: **replace Tonal Tilt (`tilt`) with Spectrogram (`spectro`)**.

3. Spectrogram (`spectro`)
   - Scrolling time x frequency sonogram of `bands[24]` on a log-frequency axis, with
     a centroid trace and an 85% rolloff line overlaid.
   - Useful answer: "How is the spectrum moving over time?" — build-ups, drops, filter
     sweeps, sustained vs. transient energy.
   - Honesty: uses only `bands`, `centroidHz`, `rolloff85Hz`. No stereo phase,
     key/chroma, or BPM. The Hz axis is the analyzer's ~45 Hz–18 kHz log band range and
     is approximate, not a calibrated FFT readout.

Why this and not "add an eighth": it keeps the grid curated at seven, removes the
weakest overlap instead of piling on, and improves the spread of questions —
shape / spectrum-now / **spectrum-over-time** / rhythm / loudness / timbre-trajectory /
low-end. `nowPlaying` and `ambient` update their suggested treatment IDs off `tilt`.

### Ideas considered and intentionally left out

- Stereo vectorscope / phase correlation — dishonest: the feed is mono-ish `waveform[32]`.
- Key / chroma wheel — no pitch-class data in `PomoAmpVizData`.
- Exact-BPM tempo grid — `bpm`/`beat*` are lab-only (0 / 1 on the native feed); Groove
  Rail already shows beat guides only when synthetic metadata exists.
- A second dynamics/loudness view (PLR-over-time) — overlaps Headroom; not worth a slot.

## Presets (face + treatment cycle)

Faces and treatments are independent layers, so most of the 6×7 pairings are valid but
only some are worth showing. A small curated `PRESETS` list (`js/presets.js`) names the
strong combinations so they can be cycled without picking both grids by hand.

Model:
- A preset = `{ id, name, face (PomoAmpFaces id), treatment (PomoAmpStyles id), note }`.
- Selecting a preset sets BOTH the face and the treatment and ensures compose mode is on
  (a preset is a composed face). The FACE and TREATMENT grids stay live for manual
  exploration; manual changes re-derive the current preset, or show "Custom" when the
  pair is off-list.
- Previous / Next cycle the list in order and wrap; a dropdown mirrors the list; `[` and
  `]` are keyboard shortcuts. A current-preset label (`name` + `n/total`) is always shown.
- Deep-link: `#preset=<id>` applies a preset on load. (`#face=<id>/<treatment>` and
  `#<treatment>` still work for ad-hoc combos.)

Acceptance:
- Previous/Next controls plus a visible current-preset label are present and work.
- Applying a preset updates face + treatment + both grids coherently and persists.
- Manual face/treatment selection updates the preset label to the match or "Custom".
- The list is small and every entry is a deliberate, legible pairing at 386x198, and
  collectively the entries exercise all seven treatments at least once.

Curated list (initial — order is the cycle order):
1. `ship` — Now Playing + Wave Trace — player-first ship candidate.
2. `console-spectro` — Studio Console + Spectrogram — spectral motion beside BANDS/WAVE.
3. `scope-headroom` — Scope Bay + Headroom — loudness/crest/headroom, measure-first.
4. `module-bandprint` — Module Stack + Bandprint EQ — Winamp density + 24-band print.
5. `ambient-spectro` — Ambient Glass + Spectrogram — sonogram colour through the cover.
6. `ambient-timbre` — Ambient Glass + Timbre Map — calm tone-colour trajectory.
7. `cinema-groove` — Cinema + Groove Rail — video stage + rhythm scrubber.
8. `cinema-wave` — Cinema + Wave Trace — video stage + waveform scrubber.
9. `console-foundation` — Studio Console + Bass Foundation — low-end health in the bay.
