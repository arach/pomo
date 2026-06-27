/* lab.js — wires the simulator + styles into a live, HUD-dimensioned study UI.
 * No build step, no dependencies: open index.html directly (file://) or serve the
 * folder. Persists last style/scenario in localStorage. */
(function () {
  "use strict";
  const { Simulator, LiveInput } = window.PomoAmpSim;
  const STYLES = window.PomoAmpStyles;
  const FACES = window.PomoAmpFaces;
  const PRESETS = window.PomoAmpPresets || [];
  const { Gentle, TRACKS } = window.PomoAmpFaceKit;
  const $ = (id) => document.getElementById(id);

  const sim = new Simulator();
  const live = new LiveInput();
  const gentle = new Gentle();
  const canvas = $("viz");
  const g = canvas.getContext("2d");
  const faceStage = $("faceStage");

  let styleIdx = 0, playing = true, frozen = false, frozenFrame = null, useLive = false;
  let lastFrame = null, t0 = performance.now() / 1000, simClock = 0, lastNow = t0;
  let fpsEMA = 60, lastFpsShow = 0;
  // face composition state
  let faceIdx = 0, compose = true, motion = "calm", trackIdx = 0, videoState = "audio";
  let presetIdx = -1; // -1 = custom (current face+treatment not on the curated list)
  let liveKind = "mic", liveLabel = "Live input";
  let deckLogical = [386, 198];
  function clampFaceIdx(i) { return Math.max(0, Math.min(FACES.length - 1, i | 0)); }

  // restore prefs
  try {
    const saved = JSON.parse(localStorage.getItem("pomoAmpVizLab") || "{}");
    if (saved.style != null) styleIdx = clampIdx(saved.style);
    if (saved.scenario) sim.setScenario(saved.scenario);
    if (saved.bpm) sim.params.bpm = saved.bpm;
    if (saved.gain != null) sim.params.gain = saved.gain;
    if (saved.face != null) faceIdx = clampFaceIdx(saved.face);
    if (saved.compose != null) compose = !!saved.compose;
    if (saved.motion) motion = saved.motion;
    if (saved.track != null) trackIdx = ((saved.track % TRACKS.length) + TRACKS.length) % TRACKS.length;
    if (saved.video) videoState = saved.video;
  } catch (e) {}
  // deep-link a treatment via #id (e.g. index.html#groove), a face via #face=studio,
  // or a face+treatment combo via #face=studio/spectro
  const hash = decodeURIComponent((location.hash || "").replace(/^#/, ""));
  const hashIdx = STYLES.findIndex((s) => s.id === hash);
  if (hashIdx >= 0) styleIdx = hashIdx;
  const fm = hash.match(/^face=(\w+)(?:[\/+](\w+))?/);
  if (fm) {
    const fi = FACES.findIndex((x) => x.id === fm[1]); if (fi >= 0) faceIdx = fi;
    if (fm[2]) { const si = STYLES.findIndex((s) => s.id === fm[2]); if (si >= 0) styleIdx = si; }
  }
  const pmatch = hash.match(/^preset=([\w-]+)/);
  let bootPresetIdx = pmatch ? PRESETS.findIndex((p) => p.id === pmatch[1]) : -1;
  function clampIdx(i) { return Math.max(0, Math.min(STYLES.length - 1, i | 0)); }
  function savePrefs() {
    try {
      localStorage.setItem("pomoAmpVizLab", JSON.stringify({
        style: styleIdx, scenario: sim.key, bpm: sim.params.bpm, gain: sim.params.gain,
        face: faceIdx, compose, motion, track: trackIdx, video: videoState,
        preset: presetIdx >= 0 && PRESETS[presetIdx] ? PRESETS[presetIdx].id : null,
      }));
    } catch (e) {}
  }

  /* ---------- build UI ---------- */
  const styleGrid = $("styleGrid");
  STYLES.forEach((s, i) => {
    const b = document.createElement("button");
    b.innerHTML = `<span class="n">${s.name}</span><span class="t">${s.port}</span>`;
    b.onclick = () => { selectStyle(i); syncPresetFromManual(); };
    styleGrid.appendChild(b);
  });
  const scenSel = $("scenario");
  sim.list().forEach((s) => {
    const o = document.createElement("option");
    o.value = s.key; o.textContent = s.name; scenSel.appendChild(o);
  });
  scenSel.value = sim.key;

  function selectStyle(i, opts) {
    opts = opts || {};
    styleIdx = clampIdx(i);
    [...styleGrid.children].forEach((c, k) => c.classList.toggle("active", k === styleIdx));
    const s = STYLES[styleIdx];
    if (s.reset) s.reset();
    $("styleBlurb").innerHTML = s.blurb;
    if (!opts.keepHash) {
      if (history.replaceState) history.replaceState(null, "", "#" + s.id);
      else location.hash = s.id;
    }
    updateHudLabel();
    savePrefs();
  }

  /* ---------- faces (composition layer) ---------- */
  const faceGrid = $("faceGrid");
  FACES.forEach((face, i) => {
    const b = document.createElement("button");
    b.innerHTML = `<span class="n">${face.name}</span><span class="t">${face.id}</span>`;
    b.onclick = () => { selectFace(i); syncPresetFromManual(); };
    faceGrid.appendChild(b);
  });
  const trackSel = $("track");
  TRACKS.forEach((tk, i) => {
    const o = document.createElement("option");
    o.value = i; o.textContent = `${tk.title} — ${tk.artist}${tk.hasVideo ? " ·video" : ""}`;
    trackSel.appendChild(o);
  });

  const actions = {
    togglePlay: () => setPlaying(!playing),
    prevTrack: () => setTrack((trackIdx - 1 + TRACKS.length) % TRACKS.length),
    nextTrack: () => setTrack((trackIdx + 1) % TRACKS.length),
    cycleVideo: () => { const o = ["audio", "player", "page"]; setVideo(o[(o.indexOf(videoState) + 1) % o.length]); },
  };

  let currentFace = null;
  function selectFace(i) {
    faceIdx = clampFaceIdx(i);
    currentFace = FACES[faceIdx];
    [...faceGrid.children].forEach((c, k) => c.classList.toggle("active", k === faceIdx));
    $("faceBlurb").innerHTML = currentFace.blurb;
    if (compose) mountFace();
    updateHudLabel();
    savePrefs();
  }
  function mountFace() {
    if (!currentFace) return;
    currentFace.mount(faceStage, actions);
    currentFace.layout(deckLogical[0], deckLogical[1]);
    gentle.reset();
    STYLES.forEach((s) => s.reset && s.reset());
  }
  function setCompose(on) {
    compose = on;
    $("composeToggle").checked = on;
    document.querySelector(".hud-deck").classList.toggle("facemode", on);
    if (on) mountFace(); else faceStage.innerHTML = "";
    STYLES.forEach((s) => s.reset && s.reset());
    updateHudLabel();
    savePrefs();
  }
  function setTrack(i) { trackIdx = i; trackSel.value = i; savePrefs(); }
  function setVideo(v) {
    videoState = v;
    [...document.querySelectorAll(".vid")].forEach((b) => b.classList.toggle("active", b.dataset.vid === v));
    savePrefs();
  }
  function setMotion(m) { motion = m; $("motion").value = m; gentle.reset(); savePrefs(); }
  function setPlaying(p) { playing = p; $("playBtn").textContent = playing ? "⏸ Pause" : "▶ Play"; }
  function updateHudLabel() {
    $("hudStyleName").textContent = compose && currentFace
      ? `${currentFace.name} · ${STYLES[styleIdx].name}` : STYLES[styleIdx].name;
  }

  /* ---------- presets (curated face + treatment combos) ---------- */
  const presetSel = $("presetPick");
  const customOpt = document.createElement("option");
  customOpt.value = ""; customOpt.textContent = "Custom combination";
  presetSel.appendChild(customOpt);
  PRESETS.forEach((p, i) => {
    const o = document.createElement("option");
    o.value = String(i); o.textContent = `${i + 1}. ${p.name}`; presetSel.appendChild(o);
  });
  const faceIdxById = (id) => FACES.findIndex((x) => x.id === id);
  const styleIdxById = (id) => STYLES.findIndex((x) => x.id === id);

  function applyPreset(i, opts) {
    opts = opts || {};
    if (!PRESETS.length) return;
    presetIdx = ((i % PRESETS.length) + PRESETS.length) % PRESETS.length;
    const p = PRESETS[presetIdx];
    if (!compose) { // a preset is a composed face — make sure it's visible
      compose = true; $("composeToggle").checked = true;
      document.querySelector(".hud-deck").classList.toggle("facemode", true);
    }
    const fi = faceIdxById(p.face); if (fi >= 0) selectFace(fi);
    const si = styleIdxById(p.treatment); if (si >= 0) selectStyle(si, { keepHash: true });
    updatePresetUI();
    if (!opts.keepHash) {
      if (history.replaceState) history.replaceState(null, "", "#preset=" + p.id);
      else location.hash = "preset=" + p.id;
    }
    savePrefs();
  }
  function cyclePreset(d) {
    const i = presetIdx < 0 ? (d > 0 ? 0 : PRESETS.length - 1) : presetIdx + d;
    applyPreset(i);
  }
  // recompute the preset label after a manual FACE/TREATMENT change
  function syncPresetFromManual() {
    const fId = currentFace ? currentFace.id : null;
    const tId = STYLES[styleIdx] ? STYLES[styleIdx].id : null;
    presetIdx = compose ? PRESETS.findIndex((p) => p.face === fId && p.treatment === tId) : -1;
    updatePresetUI();
    savePrefs();
  }
  function updatePresetUI() {
    const has = presetIdx >= 0;
    $("presetName").textContent = has ? PRESETS[presetIdx].name : "Custom";
    $("presetCount").textContent = has ? `${presetIdx + 1} / ${PRESETS.length}` : "CUSTOM · off-list";
    $("presetNote").textContent = has ? PRESETS[presetIdx].note
      : "Manual face + treatment selection — not one of the curated presets.";
    presetSel.value = has ? String(presetIdx) : "";
  }
  $("presetPrev").onclick = () => cyclePreset(-1);
  $("presetNext").onclick = () => cyclePreset(1);
  presetSel.onchange = (e) => { if (e.target.value !== "") applyPreset(+e.target.value); };

  /* ---------- sizing (true Pomo Amp deck dimensions) ---------- */
  const SIZES = { compact: [386, 198, 1], big: [640, 360, 1], compact2x: [386, 198, 2] };
  function applySize(key) {
    const hud = $("hud");
    hud.dataset.size = key;
    const [cw, ch] = SIZES[key];
    const dpr = (window.devicePixelRatio || 1);
    canvas.width = Math.round(cw * dpr);
    canvas.height = Math.round(ch * dpr);
    g.setTransform(dpr, 0, 0, dpr, 0, 0);
    canvas._logical = [cw, ch];
    deckLogical = [cw, ch];
    STYLES.forEach((s) => s.reset && s.reset());
    if (compose && currentFace) currentFace.layout(cw, ch);
    [...document.querySelectorAll(".size")].forEach((b) => b.classList.toggle("active", b.dataset.size === key));
  }

  /* ---------- inspector ---------- */
  const METRICS = [
    ["host", (f) => f.hostTime.toFixed(2)], ["media", (f) => f.mediaTime.toFixed(2)],
    ["prog", (f) => f.progress.toFixed(3)], ["rate", (f) => f.playbackRate.toFixed(2)],
    ["rms", (f) => f.rms.toFixed(3)], ["peak", (f) => f.peak.toFixed(3)],
    ["rmsdb", (f) => f.rmsDb.toFixed(1)], ["peakdb", (f) => f.peakDb.toFixed(1)],
    ["crest", (f) => f.crestDb.toFixed(1)], ["trans", (f) => f.transient.toFixed(3), (f) => f.transient > 0.5],
    ["low", (f) => f.low.toFixed(3)], ["mid", (f) => f.mid.toFixed(3)],
    ["high", (f) => f.high.toFixed(3)], ["drop", (f) => f.drop.toFixed(3), (f) => f.drop > 0.5],
    ["cent", (f) => Math.round(f.centroidHz)], ["bright", (f) => f.brightness.toFixed(3)],
    ["roll", (f) => Math.round(f.rolloff85Hz)], ["tone", (f) => f.tonality.toFixed(3)],
    ["flux", (f) => f.flux.toFixed(3)], ["onset", (f) => f.onsetPulse.toFixed(3), (f) => f.onsetPulse > 0.4],
    ["sub", (f) => f.sub.toFixed(3)], ["bass", (f) => f.bass.toFixed(3)],
    ["pres", (f) => f.presence.toFixed(3)], ["brill", (f) => f.brilliance.toFixed(3)],
  ];
  let inspCells = null;
  function buildInspector() {
    const m = $("inspMetrics"); m.innerHTML = "";
    inspCells = [];
    METRICS.forEach((row) => {
      const k = document.createElement("span"); k.className = "k"; k.textContent = row[0];
      const v = document.createElement("span"); v.className = "v";
      m.appendChild(k); m.appendChild(v); inspCells.push([v, row]);
    });
    const bandsEl = $("inspBands"); bandsEl.innerHTML = "";
    for (let i = 0; i < 24; i++) bandsEl.appendChild(document.createElement("i"));
    const waveEl = $("inspWave"); waveEl.innerHTML = "";
    for (let i = 0; i < 32; i++) waveEl.appendChild(document.createElement("i"));
  }
  function paintInspector(f) {
    if ($("inspector").classList.contains("hidden")) return;
    $("inspLed").classList.toggle("on", f.isPlaying);
    $("inspFrame").textContent = "#" + f.frame;
    for (const [el, row] of inspCells) {
      el.textContent = row[1](f);
      el.classList.toggle("hot", !!(row[2] && row[2](f)));
    }
    const bandsEl = $("inspBands").children;
    for (let i = 0; i < 24; i++) bandsEl[i].style.height = Math.max(1, f.bands[i] * 34) + "px";
    const waveEl = $("inspWave").children;
    for (let i = 0; i < 32; i++) {
      const v = f.waveform[i]; waveEl[i].style.height = Math.max(1, Math.abs(v) * 26) + "px";
      waveEl[i].style.background = v >= 0 ? "#82e6b0" : "#f5965e";
    }
  }

  /* ---------- controls ---------- */
  $("playBtn").onclick = () => setPlaying(!playing);
  $("composeToggle").onchange = (e) => { setCompose(e.target.checked); syncPresetFromManual(); };
  $("motion").onchange = (e) => setMotion(e.target.value);
  trackSel.onchange = (e) => setTrack(+e.target.value);
  [...document.querySelectorAll(".vid")].forEach((b) => b.onclick = () => setVideo(b.dataset.vid));
  $("freezeBtn").onclick = () => {
    frozen = !frozen; frozenFrame = frozen ? lastFrame : null;
    $("freezeBtn").classList.toggle("primary", frozen);
    $("freezeBtn").textContent = frozen ? "❄ Frozen" : "❄ Freeze";
  };
  scenSel.onchange = () => { sim.setScenario(scenSel.value); STYLES.forEach((s) => s.reset && s.reset()); savePrefs(); };
  $("bpm").oninput = (e) => { sim.params.bpm = +e.target.value; $("bpmVal").textContent = e.target.value; savePrefs(); };
  $("gain").oninput = (e) => { sim.params.gain = e.target.value / 100; $("gainVal").textContent = (e.target.value / 100).toFixed(1); savePrefs(); };
  [...document.querySelectorAll(".size")].forEach((b) => b.onclick = () => applySize(b.dataset.size));
  $("toggleInsp").onchange = (e) => $("inspector").classList.toggle("hidden", !e.target.checked);
  $("toggleGrid").onchange = (e) => $("hud").classList.toggle("safegrid", e.target.checked);
  // keyboard: [ / ] cycle presets (ignored while focused in a form control)
  window.addEventListener("keydown", (e) => {
    if (e.target && /^(INPUT|SELECT|TEXTAREA)$/.test(e.target.tagName)) return;
    if (e.key === "]") { e.preventDefault(); cyclePreset(1); }
    else if (e.key === "[") { e.preventDefault(); cyclePreset(-1); }
  });

  // live input — obvious in BOTH the topbar pill and (via env.live) the face header
  $("liveBtn").onchange = async (e) => {
    if (e.target.checked) {
      try { await live.useMic(); useLive = true; setLive(true, "mic", "Live input"); }
      catch (err) { $("liveHint").textContent = "mic blocked — drop an audio file on the HUD instead"; e.target.checked = false; }
    } else { live.stop(); useLive = false; setLive(false); }
  };
  function setLive(on, kind, label) {
    liveKind = kind || "mic"; liveLabel = label || "Live input";
    $("srcPill").textContent = on ? (kind || "LIVE").toUpperCase() : "SIM";
    $("srcPill").classList.toggle("live", on);
    $("liveHint").textContent = on ? "live audio → same metric pipeline · shown in face header" : "mic / drop an audio file on the HUD";
  }
  // drag-drop an audio file onto the HUD
  const hud = $("hud");
  ["dragover", "drop"].forEach((ev) => hud.addEventListener(ev, (e) => { e.preventDefault(); }));
  hud.addEventListener("drop", async (e) => {
    const file = e.dataTransfer.files && e.dataTransfer.files[0];
    if (!file || !/audio|video/.test(file.type)) return;
    try { await live.useFile(file); useLive = true; $("liveBtn").checked = true; setLive(true, "file", file.name.replace(/\.[^.]+$/, "")); }
    catch (err) { $("liveHint").textContent = "could not decode that file"; }
  });

  /* ---------- main loop ---------- */
  function loop() {
    const now = performance.now() / 1000;
    let dt = now - lastNow; lastNow = now;
    dt = Math.min(dt, 0.05);
    if (playing && !frozen) simClock += dt;

    const instFps = dt > 0 ? 1 / dt : 60;
    fpsEMA += (instFps - fpsEMA) * 0.1;
    if (now - lastFpsShow > 0.4) { $("fps").textContent = Math.round(fpsEMA) + " fps"; lastFpsShow = now; }

    let f;
    if (frozen && frozenFrame) f = frozenFrame;
    else if (useLive && live.active) { f = live.frame(simClock) || lastFrame; }
    else f = sim.frame(simClock);
    if (!f) { requestAnimationFrame(loop); return; }
    lastFrame = f;

    const dts = Math.max(dt, 0.0001);
    if (compose && currentFace) {
      // calm motion is applied at the composition level so treatments stay unchanged
      const fg = motion === "calm" ? gentle.apply(f, 0.8, dts) : f;
      const env = {
        t: simClock, dt: dts, f: fg, track: TRACKS[trackIdx], videoState, playing,
        live: { active: useLive && live.active, kind: liveKind, label: liveLabel },
        paintTreatment: (ctx, w, h) => {
          try { STYLES[styleIdx].draw(ctx, fg, { w, h, t: simClock, dt: dts }); } catch (e) {}
        },
      };
      try { currentFace.update(env); } catch (err) { console.error(err); }
    } else {
      const [w, h] = canvas._logical;
      try { STYLES[styleIdx].draw(g, f, { w, h, t: simClock, dt: dts }); }
      catch (err) { console.error(err); }
      $("progressFill").style.width = (f.progress * 100).toFixed(1) + "%";
    }

    paintInspector(f); // inspector always shows RAW (un-gentled) data — stays truthful
    requestAnimationFrame(loop);
  }

  /* ---------- boot ---------- */
  buildInspector();
  setVideo(videoState);
  $("motion").value = motion;
  $("composeToggle").checked = compose;
  trackSel.value = trackIdx;
  applySize("compact");                 // sets deckLogical + raw canvas
  selectFace(faceIdx);                  // builds/mounts the face when compose is on
  selectStyle(styleIdx, { keepHash: bootPresetIdx >= 0 }); // treatment from saved pref / #hash / default
  document.querySelector(".hud-deck").classList.toggle("facemode", compose);
  if (bootPresetIdx >= 0) applyPreset(bootPresetIdx, { keepHash: true }); // #preset=<id> overrides
  else syncPresetFromManual();          // derive preset label from restored face+treatment
  scenSel.value = sim.key;
  $("bpm").value = sim.params.bpm; $("bpmVal").textContent = sim.params.bpm;
  $("gain").value = Math.round(sim.params.gain * 100); $("gainVal").textContent = sim.params.gain.toFixed(1);
  $("footnote").innerHTML =
    "<b>PRESET</b> cycles curated face + treatment combos (◂ ▸ buttons, the dropdown, or <code>[</code> / <code>]</code>); " +
    "the FACE and TREATMENT grids stay live for manual mixing (shown as <i>Custom</i>). " +
    "<b>Faces</b> compose a treatment in player context (cover/blur, title/source/video, transport, " +
    "reserved bands + wave lanes); <b>Calm</b> motion is applied at the composition level. " +
    "Simulated <code>PomoAmpVizData</code> uses a faithful JS port of <code>PomoAmpVizAnalyzer.swift</code>; " +
    "native bridge a skin would consume is <code>window.yamp.onViz(cb)</code>. " +
    "<b>Live input</b> (mic) or dropping an audio file on the HUD shows up as <code>LIVE</code> in the face header.";
  requestAnimationFrame(loop);
})();
