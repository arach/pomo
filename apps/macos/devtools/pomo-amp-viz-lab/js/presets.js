/* presets.js — curated face + treatment combinations for the PomoAmp viz lab.
 *
 * Faces (js/faces.js) and treatments (js/styles.js) are independent layers; most
 * pairings are valid but only some are worth shipping. This is the curated short
 * list the PRESET control cycles through (previous/next, dropdown, or `[`/`]`).
 *
 *   id        : stable kebab id (used by #preset=<id> and prefs)
 *   name      : "<Face> — <Treatment>" label shown in the cycle
 *   face      : a PomoAmpFaces id   (nowplaying | modules | scopebay | ambient | studio | cinema)
 *   treatment : a PomoAmpStyles id  (wave | bandprint | spectro | groove | headroom | timbre | foundation)
 *   note      : one-line rationale for why the pairing earns a slot
 *
 * Order below IS the cycle order. Collectively the list exercises all seven treatments.
 * See TREATMENT_SPEC.md § Presets for the model + acceptance criteria.
 */
(function (global) {
  "use strict";
  global.PomoAmpPresets = [
    { id: "ship",             name: "Now Playing — Wave Trace",        face: "nowplaying", treatment: "wave",       note: "Player-first ship candidate; the waveform reads instantly as audio behind the now-playing card." },
    { id: "console-spectro",  name: "Studio Console — Spectrogram",    face: "studio",     treatment: "spectro",    note: "Engineering bay: the sonogram shows spectral motion next to first-class BANDS + WAVE panels." },
    { id: "scope-headroom",   name: "Scope Bay — Headroom",            face: "scopebay",   treatment: "headroom",   note: "Measure-first: RMS/peak/crest/headroom as the main scope, sober readouts alongside." },
    { id: "module-bandprint", name: "Module Stack — Bandprint EQ",     face: "modules",    treatment: "bandprint",  note: "Winamp-density module deck with the 24-band fingerprint living in the visualizer bay." },
    { id: "ambient-spectro",  name: "Ambient Glass — Spectrogram",     face: "ambient",    treatment: "spectro",    note: "Frosted backdrop: the sonogram bleeds spectral colour through the blurred cover." },
    { id: "ambient-timbre",   name: "Ambient Glass — Timbre Map",      face: "ambient",    treatment: "timbre",     note: "Calm mood pass: a slow tone-colour trajectory drifting over the cover." },
    { id: "cinema-groove",    name: "Cinema — Groove Rail",            face: "cinema",     treatment: "groove",     note: "Video stage with a rhythm scrubber lane — onset density and drop pressure underneath." },
    { id: "cinema-wave",      name: "Cinema — Wave Trace",             face: "cinema",     treatment: "wave",       note: "Video stage with a clean waveform scrubber for level shape." },
    { id: "console-foundation", name: "Studio Console — Bass Foundation", face: "studio", treatment: "foundation", note: "Low-end health — foundation, mud and punch — read in the engineering bay." },
  ];
})(window);
