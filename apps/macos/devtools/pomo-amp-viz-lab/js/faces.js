/* faces.js — PLAYER-FACE COMPOSITION layer for the PomoAmp viz lab.
 *
 * A "treatment" (styles.js) is the inner audio-reactive visual. A "face" is the
 * whole player composition that frames a treatment IN CONTEXT: cover art / blur /
 * translucency, title + source + video state, transport + progress, and — always —
 * reserved BANDS and WAVE lanes, even when the main treatment is a tonal map,
 * groove rail, headroom readout, or other analysis panel.
 *
 * Motion is calmed at the composition level (the Gentle smoother) rather than by
 * making treatments tamer, so the same treatments read like a music player here and
 * like a demo reel in the raw studio view. The reserved lanes are the hook the
 * sound-engineering / music-science lanes plug their future treatments into.
 *
 * Grounded in the native deck (PomoAmpHUDRootView.swift): in-deck header
 * "POMO AMP · YouTube deck · <face>", a boxed now-playing display, a spectrum strip,
 * a transport row, and AUDIO/PLAYER/PAGE video state. Faces here explore the
 * composition; they do not touch native code. */
(function (global) {
  "use strict";
  const { clamp, lerp } = global.PomoAmpSim;
  const MINT = [130, 230, 176], AMBER = [245, 150, 94], YELLOW = [234, 228, 52];
  const rgba = (c, a) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;
  const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
  const heat = (v) => v < 0.5 ? mix(MINT, AMBER, v * 2) : mix(AMBER, [255, 240, 220], (v - 0.5) * 2);

  /* ---- mock "now playing" content so faces have realistic context ---- */
  const TRACKS = [
    { title: "Midnight Drive", artist: "Auroral", source: "youtube.com", hasVideo: true,  art: [[38, 56, 132], [196, 74, 150]] },
    { title: "Glass Fields",   artist: "Kioto",   source: "soundcloud.com", hasVideo: false, art: [[20, 118, 108], [228, 178, 92]] },
    { title: "Paper Streets",  artist: "Hold Music", source: "bandcamp.com", hasVideo: true, art: [[120, 40, 64], [240, 150, 92]] },
    { title: "Slow Tide",      artist: "Möður",   source: "youtube.com", hasVideo: true,  art: [[26, 40, 60], [80, 190, 210]] },
  ];

  /* ---- small DOM + canvas helpers ---- */
  const el = (html) => { const t = document.createElement("template"); t.innerHTML = html.trim(); return t.content.firstChild; };
  function fit(cnv, w, h) {
    const dpr = global.devicePixelRatio || 1;
    cnv.width = Math.max(1, Math.round(w * dpr)); cnv.height = Math.max(1, Math.round(h * dpr));
    cnv.style.width = w + "px"; cnv.style.height = h + "px";
    const g = cnv.getContext("2d"); g.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { g, w, h };
  }
  function rr(g, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    if (g.roundRect) { g.beginPath(); g.roundRect(x, y, w, h, r); return; }
    g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r);
    g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath();
  }
  const fmtTime = (s) => { s = Math.max(0, s | 0); return (s / 60 | 0) + ":" + String(s % 60).padStart(2, "0"); };

  /* ---- procedural cover art (no external assets) ---- */
  function paintCover(g, w, h, art, t, live) {
    const [c1, c2] = live ? [[180, 70, 60], [230, 150, 80]] : art;
    const grd = g.createLinearGradient(0, 0, w, h);
    grd.addColorStop(0, `rgb(${c1.join(",")})`); grd.addColorStop(1, `rgb(${c2.join(",")})`);
    g.fillStyle = grd; g.fillRect(0, 0, w, h);
    for (let i = 0; i < 3; i++) {
      const bx = w * (0.3 + 0.42 * Math.sin(t * 0.09 + i * 2.1)), by = h * (0.32 + 0.4 * Math.cos(t * 0.11 + i * 1.7));
      const br = Math.max(w, h) * (0.32 + 0.12 * i), cc = i % 2 ? c2 : c1;
      const rg = g.createRadialGradient(bx, by, 0, bx, by, br);
      rg.addColorStop(0, `rgba(${cc.join(",")},0.55)`); rg.addColorStop(1, `rgba(${cc.join(",")},0)`);
      g.fillStyle = rg; g.fillRect(0, 0, w, h);
    }
    g.fillStyle = "rgba(0,0,0,0.18)"; g.fillRect(0, 0, w, h);
  }

  /* ---- Gentle: composition-level calming. Returns a softened COPY of a frame. ---- */
  class Gentle {
    constructor() { this.reset(); }
    reset() { this.s = {}; this.b = null; this.w = null; }
    apply(f, amount, dt) {
      if (!amount) return f;
      dt = clamp(dt, 1 / 240, 0.1);
      const a = 1 - Math.exp(-dt / lerp(0.05, 0.34, amount));
      const sm = (k) => { const c = f[k], p = this.s[k] == null ? c : this.s[k]; const v = p + (c - p) * a; this.s[k] = v; return v; };
      const out = Object.assign({}, f);
      ["rms", "peak", "low", "mid", "high", "sub", "bass", "lowMid", "presence", "brilliance",
        "brightness", "centroidHz", "flux", "tonality", "crestDb", "transient"].forEach((k) => { out[k] = sm(k); });
      if (!this.b || this.b.length !== f.bands.length) this.b = f.bands.slice();
      out.bands = f.bands.map((v, i) => { this.b[i] += (v - this.b[i]) * a; return this.b[i]; });
      const wa = 1 - Math.exp(-dt / lerp(0.02, 0.1, amount));
      if (!this.w || this.w.length !== f.waveform.length) this.w = f.waveform.slice();
      out.waveform = f.waveform.map((v, i) => { this.w[i] += (v - this.w[i]) * wa; return this.w[i]; });
      // keep onset EVENTS musical, just gentler in magnitude
      out.onsetPulse = clamp(sm("onsetPulse") * lerp(1, 0.72, amount), 0, 1);
      out.drop = clamp(f.drop * lerp(1, 0.62, amount), 0, 1.5);
      out.onset = f.onset;
      return out;
    }
  }

  /* ---- reserved lanes (always present, calm, consistent across faces) ---- */
  const Lanes = {
    bands(g, w, h, f) {
      g.clearRect(0, 0, w, h);
      const N = f.bands.length, gap = Math.max(1, w / N * 0.18), bw = (w - (N - 1) * gap) / N;
      for (let i = 0; i < N; i++) {
        const v = clamp(f.bands[i], 0, 1), bh = Math.max(1.5, v * (h - 2)), x = i * (bw + gap), y = h - bh;
        const grd = g.createLinearGradient(0, h, 0, y);
        grd.addColorStop(0, rgba(MINT, 0.55 + v * 0.35)); grd.addColorStop(1, rgba(AMBER, 0.85));
        g.fillStyle = grd; rr(g, x, y, bw, bh, Math.min(2, bw / 2)); g.fill();
      }
    },
    wave(g, w, h, f) {
      g.clearRect(0, 0, w, h);
      const wav = f.waveform, mid = h / 2;
      g.strokeStyle = "rgba(255,255,255,.06)"; g.lineWidth = 1;
      g.beginPath(); g.moveTo(0, mid); g.lineTo(w, mid); g.stroke();
      g.beginPath();
      for (let i = 0; i < wav.length; i++) {
        const x = i / (wav.length - 1) * w, y = mid + clamp(wav[i], -1, 1) * (h * 0.42);
        i ? g.lineTo(x, y) : g.moveTo(x, y);
      }
      g.lineWidth = 1.3 + f.rms * 1.6; g.strokeStyle = rgba(heat(f.brightness), 0.82);
      g.shadowBlur = 5 + f.onsetPulse * 8; g.shadowColor = rgba(heat(f.brightness), 0.6); g.stroke(); g.shadowBlur = 0;
    },
  };

  /* ---- shared chrome bits ---- */
  function sourceBadge(env) {
    if (env.live.active) return `<span class="f-badge live">● LIVE · ${env.live.kind.toUpperCase()}</span>`;
    return `<span class="f-badge">${env.track.source}</span>`;
  }
  function videoChip(env) {
    const map = { audio: "AUDIO", player: "PLAYER", page: "PAGE" };
    const on = env.videoState !== "audio";
    return `<span class="f-vid ${on ? "on" : ""}">${map[env.videoState]}</span>`;
  }
  function titleOf(env) { return env.live.active ? env.live.label : env.track.title; }
  function subOf(env) {
    if (env.live.active) return "live input";
    return `${env.track.artist}`;
  }
  function transportHTML(env) {
    return `<div class="f-transport">
      <button class="f-btn" data-act="prev" title="Previous">⏮</button>
      <button class="f-btn play" data-act="play" title="Play / pause">${env.playing ? "⏸" : "▶"}</button>
      <button class="f-btn" data-act="next" title="Next">⏭</button>
      <span class="f-div"></span>
      <button class="f-btn" data-act="video" title="Cycle video state">▭</button>
    </div>`;
  }
  function progressHTML() {
    return `<div class="f-progwrap"><span class="f-time cur">0:00</span>
      <div class="f-prog"><div class="f-prog-fill"></div></div>
      <span class="f-time dur">0:00</span></div>`;
  }
  function wire(root, actions) {
    root.querySelectorAll("[data-act]").forEach((b) => b.onclick = (e) => {
      e.stopPropagation();
      const a = b.dataset.act;
      if (a === "play") actions.togglePlay();
      else if (a === "prev") actions.prevTrack();
      else if (a === "next") actions.nextTrack();
      else if (a === "video") actions.cycleVideo();
    });
  }
  const VIDLABEL = { audio: "AUDIO", player: "PLAYER", page: "PAGE" };
  function paintChrome(r, env) {
    if (r.title) r.title.textContent = titleOf(env);
    if (r.sub) r.sub.textContent = subOf(env);
    if (r.state) { r.state.textContent = env.playing ? "PLAYING" : "READY"; r.state.classList.toggle("playing", env.playing); }
    if (r.badge) {
      r.badge.textContent = env.live.active ? `● LIVE · ${env.live.kind.toUpperCase()}` : env.track.source;
      r.badge.classList.toggle("live", env.live.active);
    }
    if (r.vid) { r.vid.textContent = VIDLABEL[env.videoState]; r.vid.classList.toggle("on", env.videoState !== "audio"); }
    if (r.play) r.play.textContent = env.playing ? "⏸" : "▶";
    if (r.fill) r.fill.style.width = (env.f.progress * 100).toFixed(1) + "%";
    if (r.cur) r.cur.textContent = fmtTime(env.f.mediaTime);
    if (r.dur) r.dur.textContent = fmtTime(env.f.duration);
  }
  const grabChrome = (root) => ({
    root,
    title: root.querySelector(".f-title"), sub: root.querySelector(".f-sub"),
    state: root.querySelector(".f-state"), badge: root.querySelector(".f-badge"),
    vid: root.querySelector(".f-vid"), play: root.querySelector(".f-btn.play"),
    fill: root.querySelector(".f-prog-fill"), cur: root.querySelector(".f-time.cur"), dur: root.querySelector(".f-time.dur"),
  });

  /* =====================================================================
     FACE 1 — "Now Playing" (the starting face we might ship)
     Calm: treatment is a dim screen-blended backdrop over blurred cover; a
     glass card holds title/source/video + transport + progress; reserved
     bands + wave lanes sit as a slim strip. Treatment is accent, not hero.
     ===================================================================== */
  const nowPlaying = {
    id: "nowplaying", name: "Now Playing", suggest: "wave", screen: true,
    blurb: "Calm <b>starting-face</b> candidate. Treatment is a dim backdrop behind a glass now-playing card; reserved <b>bands + wave</b> strip below. Reads as a player first, visualizer second.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face npl">
        <canvas class="face-cover"></canvas>
        <canvas class="face-treat blend-screen dim"></canvas>
        <div class="npl-head">
          <span class="f-kicker">POMO AMP</span><span class="f-deck">audio deck</span>
          ${videoChip({ videoState: "audio" })}
        </div>
        <div class="npl-card glass">
          <canvas class="npl-art"></canvas>
          <div class="npl-meta">
            <div class="f-title">—</div>
            <div class="npl-line"><span class="f-state">READY</span>${sourceBadge({ live: { active: false }, track: { source: "" } })}<span class="f-sub">—</span></div>
          </div>
        </div>
        <div class="npl-lanes">
          <div class="lane"><span class="lane-label">BANDS</span><canvas class="lane-bands"></canvas></div>
          <div class="lane"><span class="lane-label">WAVE</span><canvas class="lane-wave"></canvas></div>
        </div>
        ${transportHTML({ playing: true })}
        ${progressHTML()}
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.cover = root.querySelector(".face-cover"); this.treat = root.querySelector(".face-treat");
      this.art = root.querySelector(".npl-art"); this.bands = root.querySelector(".lane-bands"); this.wave = root.querySelector(".lane-wave");
    },
    layout(w, h) {
      this.cc = fit(this.cover, w, h); this.tc = fit(this.treat, w, h);
      const laneW = Math.max(64, Math.floor((w - 30) / 2));
      this.ac = fit(this.art, 46, 46);
      this.bc = fit(this.bands, laneW, 22);
      this.wc = fit(this.wave, laneW, 20);
    },
    update(env) {
      paintCover(this.cc.g, this.cc.w, this.cc.h, env.track.art, env.t, env.live.active);
      paintCover(this.ac.g, this.ac.w, this.ac.h, env.track.art, env.t, env.live.active);
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      Lanes.wave(this.wc.g, this.wc.w, this.wc.h, env.f);
      paintChrome(this.r, env);
    },
  };

  /* =====================================================================
     FACE 2 — "Ambient Glass" — treatment is the hero but calm & dimmed;
     a frosted glass bar at the bottom carries the controls; reserved lanes
     live inside the glass. Maximum translucency / blur feel.
     ===================================================================== */
  const ambient = {
    id: "ambient", name: "Ambient Glass", suggest: "spectro", screen: true,
    blurb: "Treatment as a <b>calm, dimmed backdrop</b> over a color-washed cover; a frosted-glass control bar floats the transport + reserved lanes on top. Showcases translucency / blur.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face amb">
        <canvas class="face-cover heavy"></canvas>
        <canvas class="face-treat blend-screen"></canvas>
        <div class="amb-top">
          <div class="f-title">—</div>
          <div class="amb-sub"><span class="f-state">READY</span>${sourceBadge({ live: { active: false }, track: { source: "" } })}${videoChip({ videoState: "audio" })}<span class="f-sub"></span></div>
        </div>
        <div class="amb-bar glass">
          ${transportHTML({ playing: true })}
          <div class="amb-lanes">
            <canvas class="lane-bands"></canvas>
            <canvas class="lane-wave"></canvas>
          </div>
          ${progressHTML()}
        </div>
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.cover = root.querySelector(".face-cover"); this.treat = root.querySelector(".face-treat");
      this.bands = root.querySelector(".lane-bands"); this.wave = root.querySelector(".lane-wave");
    },
    layout(w, h) {
      this.cc = fit(this.cover, w, h); this.tc = fit(this.treat, w, h);
      const lw = (w - 40) / 2;
      this.bc = fit(this.bands, lw, 18); this.wc = fit(this.wave, lw, 18);
    },
    update(env) {
      paintCover(this.cc.g, this.cc.w, this.cc.h, env.track.art, env.t, env.live.active);
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      Lanes.wave(this.wc.g, this.wc.w, this.wc.h, env.f);
      paintChrome(this.r, env);
    },
  };

  /* =====================================================================
     FACE 3 — "Studio Console" — engineering composition. Treatment is one
     contained module; BANDS and WAVE are first-class labeled panels with
     tick guides — the slot the music-science treatments plug into.
     ===================================================================== */
  const studio = {
    id: "studio", name: "Studio Console", suggest: "bandprint", screen: false,
    blurb: "Engineering composition: the treatment is a contained module beside <b>first-class BANDS + WAVE panels</b> with guides. The slot for future sound-science treatments; metering context up front.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face std">
        <div class="std-head">
          <span class="f-kicker">POMO AMP</span><span class="f-deck">console</span>
          <span class="f-title">—</span><span class="f-sub"></span>
          <span class="std-spacer"></span>
          ${sourceBadge({ live: { active: false }, track: { source: "" } })}${videoChip({ videoState: "audio" })}
          <span class="f-state">READY</span>
        </div>
        <div class="std-body">
          <div class="std-pane main"><span class="lane-label">TREATMENT</span><canvas class="face-treat"></canvas></div>
          <div class="std-side">
            <div class="std-pane"><span class="lane-label">BANDS</span><canvas class="lane-bands"></canvas></div>
            <div class="std-pane"><span class="lane-label">WAVE</span><canvas class="lane-wave"></canvas></div>
          </div>
        </div>
        <div class="std-foot">
          ${transportHTML({ playing: true })}
          ${progressHTML()}
        </div>
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.treat = root.querySelector(".face-treat"); this.bands = root.querySelector(".lane-bands"); this.wave = root.querySelector(".lane-wave");
    },
    layout(w, h) {
      const bodyH = h - 78, mainW = Math.round((w - 24) * 0.56), sideW = (w - 24) - mainW - 8;
      this.tc = fit(this.treat, mainW - 2, bodyH - 16);
      this.bc = fit(this.bands, sideW - 2, Math.round((bodyH - 8) / 2) - 16);
      this.wc = fit(this.wave, sideW - 2, Math.round((bodyH - 8) / 2) - 16);
    },
    update(env) {
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      Lanes.wave(this.wc.g, this.wc.w, this.wc.h, env.f);
      paintChrome(this.r, env);
    },
  };

  /* =====================================================================
     FACE 4 — "Cinema" — video-forward. A 16:9 video area shows video state
     (AUDIO art / PLAYER / PAGE); the treatment is a slim scrubber-lane under
     it; a reserved bands mini-lane keeps spectral context.
     ===================================================================== */
  const cinema = {
    id: "cinema", name: "Cinema", suggest: "wave", screen: false,
    blurb: "Video-forward: a 16:9 stage reflects <b>video state</b> (audio art / player / page) with the treatment as a slim <b>scrubber lane</b> beneath, plus a reserved bands mini-lane. Title + source overlaid.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face cin">
        <div class="cin-screen">
          <canvas class="face-cover"></canvas>
          <div class="cin-overlay">
            <div class="cin-top">${sourceBadge({ live: { active: false }, track: { source: "" } })}${videoChip({ videoState: "audio" })}</div>
            <div class="cin-title"><div class="f-title">—</div><div class="f-sub"></div></div>
          </div>
        </div>
        <div class="cin-scrub"><canvas class="face-treat"></canvas></div>
        <div class="cin-foot">
          ${transportHTML({ playing: true })}
          <canvas class="lane-bands"></canvas>
          ${progressHTML()}
        </div>
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.cover = root.querySelector(".face-cover"); this.treat = root.querySelector(".face-treat"); this.bands = root.querySelector(".lane-bands");
      this.screen = root.querySelector(".cin-screen");
    },
    layout(w, h) {
      const sh = Math.max(60, h - 108); // reserve ~108 for scrubber + foot
      this.screen.style.height = sh + "px"; // children are absolute → needs explicit height
      this.cc = fit(this.cover, w, sh);
      this.tc = fit(this.treat, w - 8, 26);
      this.bc = fit(this.bands, Math.round(w * 0.34), 22);
    },
    update(env) {
      // PAGE state dims the video & shows a "page" tint; PLAYER is bright; AUDIO shows art
      paintCover(this.cc.g, this.cc.w, this.cc.h, env.track.art, env.t, env.live.active);
      this.screen.classList.toggle("page", env.videoState === "page");
      this.screen.classList.toggle("audioonly", env.videoState === "audio");
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      paintChrome(this.r, env);
    },
  };

  /* =====================================================================
     FACE 5 — "Module Stack" — Winamp/classic-skin influence without cosplay:
     hard modules, tiny controls, stateful strips, and a sprite-sized meter rail.
     Cover art is present but boxed; treatment reads like the old visualizer bay.
     ===================================================================== */
  const moduleStack = {
    id: "modules", name: "Module Stack", suggest: "bandprint", screen: false,
    blurb: "Winamp-ish discipline: hard-edged stacked modules, tiny state strips, boxed cover, and a visualizer bay. Less rounded, more <b>bitmap-panel</b> than glass card.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face mod">
        <canvas class="face-cover"></canvas>
        <div class="mod-bar">
          <span class="f-kicker">POMO AMP</span><span class="f-deck">module</span>
          <span class="f-title">—</span><span class="mod-spacer"></span>
          ${videoChip({ videoState: "audio" })}
        </div>
        <div class="mod-display"><span class="lane-label">VIS</span><canvas class="face-treat"></canvas></div>
        <div class="mod-info">
          <canvas class="mod-art"></canvas>
          <div class="mod-copy">
            <div><span class="f-state">READY</span>${sourceBadge({ live: { active: false }, track: { source: "" } })}</div>
            <span class="f-sub"></span>
            <div class="mod-read"><span>RMS <b class="mod-rms">0.00</b></span><span>CREST <b class="mod-crest">0.0</b></span><span>BRIGHT <b class="mod-bright">0.00</b></span></div>
          </div>
          <div class="mod-bandbox"><span class="lane-label">BANDS</span><canvas class="lane-bands"></canvas></div>
        </div>
        <div class="mod-wave"><span class="lane-label">WAVE</span><canvas class="lane-wave"></canvas></div>
        <div class="mod-foot">${transportHTML({ playing: true })}${progressHTML()}</div>
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.cover = root.querySelector(".face-cover"); this.treat = root.querySelector(".face-treat");
      this.art = root.querySelector(".mod-art"); this.bands = root.querySelector(".lane-bands"); this.wave = root.querySelector(".lane-wave");
      this.read = {
        rms: root.querySelector(".mod-rms"),
        crest: root.querySelector(".mod-crest"),
        bright: root.querySelector(".mod-bright"),
      };
    },
    layout(w, h) {
      this.cc = fit(this.cover, w, h);
      this.tc = fit(this.treat, w - 20, Math.max(38, Math.round(h * 0.28)));
      this.ac = fit(this.art, 42, 42);
      this.bc = fit(this.bands, Math.max(90, Math.round(w * 0.31)), 34);
      this.wc = fit(this.wave, w - 20, 18);
    },
    update(env) {
      paintCover(this.cc.g, this.cc.w, this.cc.h, env.track.art, env.t, env.live.active);
      paintCover(this.ac.g, this.ac.w, this.ac.h, env.track.art, env.t, env.live.active);
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      Lanes.wave(this.wc.g, this.wc.w, this.wc.h, env.f);
      this.read.rms.textContent = env.f.rms.toFixed(2);
      this.read.crest.textContent = env.f.crestDb.toFixed(1);
      this.read.bright.textContent = env.f.brightness.toFixed(2);
      paintChrome(this.r, env);
    },
  };

  /* =====================================================================
     FACE 6 — "Scope Bay" — pro audio / video tool influence: a quiet bay of
     technical panes. The treatment is one scope, BANDS is the parade-style
     readout, WAVE is the waveform lane, and the footer keeps player state.
     ===================================================================== */
  const scopeBay = {
    id: "scopebay", name: "Scope Bay", suggest: "headroom", screen: false,
    blurb: "Professional-tool presentation: boxed scopes, sober readouts, and a video/audio bay layout. More Resolve/Ableton than screensaver: <b>measure first, decorate second</b>.",
    mount(stage, actions) {
      stage.innerHTML = "";
      const root = el(`<div class="face scp">
        <div class="scp-head">
          <span class="f-kicker">POMO AMP</span><span class="f-deck">scope bay</span>
          ${sourceBadge({ live: { active: false }, track: { source: "" } })}
          ${videoChip({ videoState: "audio" })}
          <span class="f-state">READY</span>
        </div>
        <div class="scp-grid">
          <div class="scp-pane scp-main"><span class="lane-label">SCOPE</span><canvas class="face-treat"></canvas></div>
          <div class="scp-stack">
            <div class="scp-pane"><span class="lane-label">BANDS</span><canvas class="lane-bands"></canvas></div>
            <div class="scp-pane"><span class="lane-label">WAVEFORM</span><canvas class="lane-wave"></canvas></div>
            <div class="scp-readout">
              <span><b class="scp-rms">0.00</b> RMS</span>
              <span><b class="scp-peak">0.00</b> PK</span>
              <span><b class="scp-cent">0</b> Hz</span>
            </div>
          </div>
        </div>
        <div class="scp-foot">
          <div class="scp-title"><span class="f-title">—</span><span class="f-sub"></span></div>
          ${transportHTML({ playing: true })}
        </div>
        ${progressHTML()}
      </div>`);
      stage.appendChild(root); wire(root, actions);
      this.root = root; this.r = grabChrome(root);
      this.treat = root.querySelector(".face-treat"); this.bands = root.querySelector(".lane-bands"); this.wave = root.querySelector(".lane-wave");
      this.read = {
        rms: root.querySelector(".scp-rms"),
        peak: root.querySelector(".scp-peak"),
        cent: root.querySelector(".scp-cent"),
      };
    },
    layout(w, h) {
      const bodyH = Math.max(74, h - 70);
      const mainW = Math.round((w - 28) * 0.58);
      const sideW = w - 28 - mainW - 8;
      this.tc = fit(this.treat, mainW - 2, bodyH - 16);
      this.bc = fit(this.bands, sideW - 2, Math.round(bodyH * 0.38) - 13);
      this.wc = fit(this.wave, sideW - 2, Math.round(bodyH * 0.35) - 13);
    },
    update(env) {
      env.paintTreatment(this.tc.g, this.tc.w, this.tc.h);
      Lanes.bands(this.bc.g, this.bc.w, this.bc.h, env.f);
      Lanes.wave(this.wc.g, this.wc.w, this.wc.h, env.f);
      this.read.rms.textContent = env.f.rms.toFixed(2);
      this.read.peak.textContent = env.f.peak.toFixed(2);
      this.read.cent.textContent = Math.round(env.f.centroidHz);
      paintChrome(this.r, env);
    },
  };

  global.PomoAmpFaces = [nowPlaying, moduleStack, scopeBay, ambient, studio, cinema];
  global.PomoAmpFaceKit = { Gentle, Lanes, TRACKS, paintCover };
})(window);
