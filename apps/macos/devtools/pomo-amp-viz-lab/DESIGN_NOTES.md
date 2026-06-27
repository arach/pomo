# Pomo Amp Viz Lab Design Notes

This lab should feel like a compact music instrument, not a rounded dashboard.
The visual language can still use Pomo Amp's mint/amber/black palette, cover blur,
and translucency, but the structure should be more disciplined: hard modules,
thin borders, small controls, clear states, and measurement lanes with purpose.

## Research Anchors

- Winamp Skin Museum: https://skins.webamp.org/
  The useful lesson is density and recognizability. Tiny compositions still read
  when the silhouette, control placement, and state changes are crisp.
- Jordan Eldredge on the museum: https://jordaneldredge.com/winamp-skin-musuem/
  The museum works because it maximizes image density and "Winamp essence" per
  screenshot. For Pomo Amp, each face should have a strong silhouette at 386x198.
- Wired on skins: https://www.wired.com/2000/10/skins/
  Skins became emotional software. The face can be expressive, but it still has
  to preserve the reliable controls users expect from a player.
- Classic Winamp skin tutorial: https://winampskins.neocities.org/main
  Winamp's main window is assembled from many bitmap parts: title bars, buttons,
  pressed states, shuffle/repeat states, volume bars, and visualization regions.
  Translate that into Pomo Amp as visible modules and stateful micro-controls.
- Winamp template notes: https://www.alpha-ii.com/Info/Template.html
  Small fixed assets matter: the position bar, 5x6 title font, button states,
  visualizer colors, and tiny slider strips. This argues for compact typography,
  short labels, and functional rails.
- Ableton Live mixer manual: https://www.ableton.com/en/manual/mixing/
  Professional audio UIs are modular and selectively reveal components. Meters,
  crossfader, routing, and performance indicators are shown when useful.
- Avid gain staging guide: https://www.avid.com/resource-center/gain-staging-guide
  Pro audio metering is not decoration. Level, headroom, crest, and clipping
  indicators should communicate decisions.
- Blackmagic Video Assist scopes: https://www.blackmagicdesign.com/products/blackmagicvideoassist/scopes
  Video tools use waveform, parade, vectorscope, and histogram as measurement
  panes, sometimes full-screen and sometimes overlayed on picture. This maps well
  to Pomo Amp's BANDS/WAVE lanes and future phase/timbre scopes.

## Translation Rules

- Prefer 0-6px radius. Reserve circles for LEDs and native traffic-light dots.
- Use panels, rails, dividers, and small labels before floating cards.
- A face needs one dominant job: player, module, scope bay, video stage, or meter.
- Always keep BANDS and WAVE somewhere stable, even when the treatment changes.
- Treat cover art as context, not wallpaper. If blurred, it should support the
  hierarchy rather than flood the face.
- Avoid motion as spectacle. Motion should report music: level, onset, brightness,
  density, or video state.
- Hard state changes are good: AUDIO/PLAYER/PAGE, LIVE/SIM, PLAYING/READY,
  clipping/headroom, and selected transport states.

## Current Face Intent

- Now Playing: ship candidate, player-first.
- Module Stack: Winamp-inspired hard modules and sprite-like state strips.
- Scope Bay: pro audio/video scope layout, measurement-first.
- Ambient Glass: translucent cover and treatment-forward mood pass.
- Studio Console: engineering layout for dense metering treatments.
- Cinema: video-forward state study.
