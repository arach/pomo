/* styles.js - grounded PomoAmp visualization treatments.
 *
 * Each treatment: { id, name, blurb, port, reset(), draw(g, f, env) }
 *   g    : CanvasRenderingContext2D (already DPR-scaled; draw in CSS px)
 *   f    : a full PomoAmpVizData frame (see sim.js)
 *   env  : { w, h, t, dt } logical size + clock
 *
 * See TREATMENT_SPEC.md for the pruning rules. The treatment list is deliberately
 * less "screensaver" and more "what can a listener learn about the track?".
 */
(function (global) {
  "use strict";
  const { clamp, lerp, CENTERS } = global.PomoAmpSim;

  const MINT = [130, 230, 176], AMBER = [245, 150, 94], YELLOW = [234, 228, 52], BLUE = [120, 180, 245];
  const rgba = (c, a) => `rgba(${c[0] | 0},${c[1] | 0},${c[2] | 0},${a})`;
  const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
  const heat = (v) => v < 0.5 ? mix(MINT, AMBER, v * 2) : mix(AMBER, [255, 240, 220], (v - 0.5) * 2);
  // sonogram ramp: dark → blue → mint → amber → white as energy rises
  const spectroHeat = (v) => {
    v = clamp(v, 0, 1);
    if (v < 0.32) return mix([9, 13, 20], BLUE, v / 0.32);
    if (v < 0.62) return mix(BLUE, MINT, (v - 0.32) / 0.30);
    if (v < 0.88) return mix(MINT, AMBER, (v - 0.62) / 0.26);
    return mix(AMBER, [255, 240, 220], (v - 0.88) / 0.12);
  };
  const clamp01 = (v) => clamp(v, 0, 1);
  const logHz = (hz) => clamp((Math.log(Math.max(40, hz)) - Math.log(40)) / (Math.log(16000) - Math.log(40)), 0, 1);
  const dbNorm = (db, floor) => clamp((db - floor) / -floor, 0, 1);

  function rising(self, f) {
    const fired = f.onset && !self._wasOnset;
    self._wasOnset = f.onset;
    return fired;
  }
  function bg(g, w, h) {
    g.clearRect(0, 0, w, h);
    g.fillStyle = "#050607"; g.fillRect(0, 0, w, h);
  }
  function label(g, txt, x, y, color) {
    g.font = "8px monospace";
    g.fillStyle = color || "rgba(255,255,255,.36)";
    g.fillText(txt, x, y);
  }
  function grid(g, w, h, cols, rows) {
    g.strokeStyle = "rgba(255,255,255,.055)";
    g.lineWidth = 1;
    g.beginPath();
    for (let i = 1; i < cols; i++) { const x = i / cols * w; g.moveTo(x, 0); g.lineTo(x, h); }
    for (let i = 1; i < rows; i++) { const y = i / rows * h; g.moveTo(0, y); g.lineTo(w, y); }
    g.stroke();
  }
  /* ---------- 1. Wave Trace ---------- */
  const waveTrace = {
    id: "wave", name: "Wave Trace", port: "trivial - direct canvas port",
    blurb: "Waveform plus <b>RMS envelope</b> and onset ticks. Keeps the instant 'audio' read, but adds level shape and transient timing instead of plain oscilloscope motion.",
    reset() { this.hist = []; this.env = []; this.ticks = []; },
    draw(g, f, { w, h, dt }) {
      bg(g, w, h);
      grid(g, w, h, 4, 4);
      const mid = h * 0.46;
      this.hist.unshift(f.waveform.slice());
      if (this.hist.length > 12) this.hist.pop();
      this.env.push({ rms: f.rms, peak: f.peak });
      if (this.env.length > Math.max(32, w | 0)) this.env.shift();
      if (rising(this, f)) this.ticks.push({ x: w, a: 1, d: f.drop });
      const col = heat(f.brightness);

      for (let k = this.hist.length - 1; k >= 0; k--) {
        const wav = this.hist[k], age = k / 12, amp = h * (0.30 - age * 0.10), yOff = -age * h * 0.22;
        g.beginPath();
        for (let i = 0; i < wav.length; i++) {
          const x = (i / (wav.length - 1)) * w;
          const y = mid + yOff + wav[i] * amp;
          i ? g.lineTo(x, y) : g.moveTo(x, y);
        }
        g.lineWidth = k === 0 ? 1.4 + f.rms * 2.4 : 1;
        g.strokeStyle = rgba(col, k === 0 ? 0.95 : 0.13 * (1 - age));
        g.stroke();
      }

      const base = h - 18;
      g.strokeStyle = "rgba(255,255,255,.10)";
      g.beginPath(); g.moveTo(0, base); g.lineTo(w, base); g.stroke();
      g.beginPath();
      this.env.forEach((e, i) => {
        const x = (i / Math.max(1, this.env.length - 1)) * w;
        const y = base - e.rms * h * 0.34;
        i ? g.lineTo(x, y) : g.moveTo(x, y);
      });
      g.lineWidth = 1.2; g.strokeStyle = rgba(MINT, 0.82); g.stroke();

      for (let i = this.ticks.length - 1; i >= 0; i--) {
        const t = this.ticks[i]; t.x -= Math.max(18, w * 0.22) * dt; t.a -= dt * 0.55;
        if (t.x < 0 || t.a <= 0) { this.ticks.splice(i, 1); continue; }
        g.strokeStyle = rgba(AMBER, t.a); g.lineWidth = 1 + t.d * 2.5;
        g.beginPath(); g.moveTo(t.x, h - 2); g.lineTo(t.x, h - 2 - h * (0.18 + t.d * 0.22)); g.stroke();
      }
      label(g, "WAVE", 7, 12); label(g, "ENV", 7, h - 8);
    },
  };

  /* ---------- 2. Bandprint EQ ---------- */
  const bandprint = {
    id: "bandprint", name: "Bandprint EQ", port: "easy - canvas bars + peak holds",
    blurb: "A disciplined <b>24-band spectral fingerprint</b>: grouped labels, peak holds, centroid marker, and tilt cue. Reframes the spectrum as useful EQ context.",
    reset() { this.peaks = null; },
    draw(g, f, { w, h, dt }) {
      bg(g, w, h);
      const pad = 10, top = 18, bot = h - 24, N = f.bands.length;
      if (!this.peaks || this.peaks.length !== N) this.peaks = new Array(N).fill(0);
      grid(g, w, h, 6, 4);
      const gap = Math.max(1, w / N * 0.16), bw = (w - pad * 2 - gap * (N - 1)) / N;
      for (let i = 0; i < N; i++) {
        const v = clamp01(f.bands[i]), x = pad + i * (bw + gap), bh = v * (bot - top), y = bot - bh;
        const c = heat(i / (N - 1));
        g.fillStyle = rgba(c, 0.18); g.fillRect(x, top, bw, bot - top);
        g.fillStyle = rgba(c, 0.78 + v * 0.18); g.fillRect(x, y, bw, bh);
        this.peaks[i] = Math.max(v, this.peaks[i] - dt * 0.55);
        g.fillStyle = "rgba(255,240,220,.82)";
        g.fillRect(x, bot - this.peaks[i] * (bot - top) - 1, bw, 1);
      }
      const cx = pad + logHz(f.centroidHz) * (w - pad * 2);
      g.strokeStyle = rgba(YELLOW, 0.9); g.lineWidth = 1;
      g.beginPath(); g.moveTo(cx, top - 5); g.lineTo(cx, bot + 6); g.stroke();
      label(g, `${Math.round(f.centroidHz)} Hz`, Math.min(w - 58, cx + 4), top - 7, rgba(YELLOW, .8));

      const tilt = clamp01(((f.presence + f.brilliance) - (f.sub + f.bass) * 0.5 + 1) / 2);
      g.strokeStyle = rgba(heat(tilt), 0.75); g.lineWidth = 1.4;
      g.beginPath();
      g.moveTo(pad, lerp(bot, top, clamp01(f.sub + f.bass)));
      g.lineTo(w - pad, lerp(bot, top, clamp01(f.presence + f.brilliance)));
      g.stroke();
      [["SUB", .06], ["BASS", .22], ["MID", .48], ["PRES", .70], ["AIR", .90]].forEach(([txt, p]) => label(g, txt, pad + p * (w - pad * 2) - 8, h - 8));
    },
  };

  /* ---------- 3. Spectrogram ---------- */
  const spectrogram = {
    id: "spectro", name: "Spectrogram", port: "moderate - offscreen scroll buffer",
    blurb: "A scrolling <b>time × frequency sonogram</b> of the 24 bands on a log-Hz axis, with a <b>centroid</b> trace and 85% <b>rolloff</b> line. Answers how the spectrum moves — build-ups, drops, sweeps — not just where it sits now.",
    reset() { this.buf = null; this.cHist = []; this.rHist = []; this.W = 0; this.H = 0; },
    draw(g, f, { w, h }) {
      bg(g, w, h);
      const top = 13, bot = h - 4, plotH = bot - top, axisW = 26, plotW = Math.max(8, w - axisW);
      // log-frequency placement: low at bottom, high at top
      const yOf = (hz) => plotH - logHz(hz) * plotH;
      // offscreen scroll buffer (heatmap only); overlays are redrawn from history
      if (!this.buf) this.buf = document.createElement("canvas");
      if (this.W !== plotW || this.H !== plotH) {
        this.W = plotW; this.H = plotH; this.buf.width = plotW; this.buf.height = plotH;
        this.cHist = []; this.rHist = [];
      }
      const bc = this.buf.getContext("2d");
      bc.drawImage(this.buf, -1, 0); // scroll left 1px/frame
      const N = f.bands.length, x0 = plotW - 1;
      const bnd = new Array(N + 1); bnd[0] = plotH; bnd[N] = 0;
      for (let i = 1; i < N; i++) bnd[i] = yOf(Math.sqrt(CENTERS[i - 1] * CENTERS[i]));
      bc.clearRect(x0, 0, 1, plotH);
      for (let i = 0; i < N; i++) {
        const yTop = bnd[i + 1], cell = Math.max(1, bnd[i] - bnd[i + 1]);
        bc.fillStyle = rgba(spectroHeat(clamp01(f.bands[i])), 1);
        bc.fillRect(x0, yTop, 1, cell);
      }
      g.drawImage(this.buf, 0, top);

      // centroid + rolloff history overlays, aligned to the same 1px/frame scroll
      this.cHist.push(yOf(f.centroidHz)); this.rHist.push(yOf(f.rolloff85Hz));
      if (this.cHist.length > plotW) this.cHist.shift();
      if (this.rHist.length > plotW) this.rHist.shift();
      const drawTrace = (hist, color, lw, alpha) => {
        const base = plotW - hist.length;
        g.beginPath();
        for (let i = 0; i < hist.length; i++) { const x = base + i, y = top + hist[i]; i ? g.lineTo(x, y) : g.moveTo(x, y); }
        g.strokeStyle = rgba(color, alpha); g.lineWidth = lw; g.stroke();
      };
      drawTrace(this.rHist, [255, 240, 220], 1, 0.5);
      drawTrace(this.cHist, YELLOW, 1.4, 0.92);

      // right Hz axis
      g.fillStyle = "#050607"; g.fillRect(plotW, top, axisW, plotH);
      [[100, "100"], [1000, "1k"], [10000, "10k"]].forEach(([hz, txt]) => {
        const y = top + yOf(hz);
        g.strokeStyle = "rgba(255,255,255,.10)"; g.beginPath(); g.moveTo(plotW, y); g.lineTo(plotW + 3, y); g.stroke();
        label(g, txt, plotW + 5, y + 3);
      });
      label(g, "SPECTROGRAM", 7, 11, rgba(MINT, .8));
      label(g, `CENT ${Math.round(f.centroidHz)}Hz`, 7, h - 6, rgba(YELLOW, .8));
    },
  };

  /* ---------- 4. Groove Rail ---------- */
  const grooveRail = {
    id: "groove", name: "Groove Rail", port: "easy - scrolling history",
    blurb: "A rhythm readout: <b>onset ticks, transient density, drop pressure</b>, and beat/bar guides when available. This keeps bloom's useful event signal and drops the empty spectacle.",
    reset() { this.hist = []; },
    draw(g, f, { w, h }) {
      bg(g, w, h);
      this.hist.push({ o: f.onsetPulse, tr: f.transient, rms: f.rms, drop: f.drop, on: f.onset });
      if (this.hist.length > Math.max(48, w | 0)) this.hist.shift();
      const top = 18, bot = h - 30, base = bot;
      grid(g, w, h, 8, 4);
      if (f.bpm > 0) {
        const phaseX = (1 - (f.beatPhase % 1)) * w;
        g.strokeStyle = "rgba(234,228,52,.18)";
        for (let x = phaseX; x < w; x += w / 4) { g.beginPath(); g.moveTo(x, top); g.lineTo(x, bot); g.stroke(); }
      }
      this.hist.forEach((p, i) => {
        const x = (i / Math.max(1, this.hist.length - 1)) * w;
        const trH = p.tr * (bot - top);
        g.strokeStyle = rgba(p.on ? AMBER : MINT, p.on ? .95 : .28 + p.o * .35);
        g.lineWidth = p.on ? 2.2 : 1;
        g.beginPath(); g.moveTo(x, base); g.lineTo(x, base - Math.max(2, trH)); g.stroke();
        if (p.drop > 0.35) { g.fillStyle = rgba(AMBER, p.drop * .16); g.fillRect(x, top, 2, bot - top); }
      });
      const avg = this.hist.reduce((a, p) => a + p.o, 0) / Math.max(1, this.hist.length);
      const busy = this.hist.reduce((a, p) => a + (p.tr > .25 ? 1 : 0), 0) / Math.max(1, this.hist.length);
      label(g, "ONSET", 8, 12);
      label(g, `DENS ${busy.toFixed(2)}`, w - 78, 12, rgba(MINT, .8));
      label(g, `DROP ${clamp01(f.drop).toFixed(2)}`, w - 78, h - 8, rgba(AMBER, .8));
      g.fillStyle = rgba(MINT, .22); g.fillRect(8, h - 20, w - 16, 5);
      g.fillStyle = rgba(AMBER, .8); g.fillRect(8, h - 20, (w - 16) * clamp01(avg * 2), 5);
    },
  };

  /* ---------- 5. Headroom ---------- */
  const headroom = {
    id: "headroom", name: "Headroom", port: "easy - canvas meters",
    blurb: "Compact loudness view: <b>RMS, peak, crest, transient, and headroom</b>. Useful for judging loud/punchy/compressed behavior without pretending to be a mastering suite.",
    reset() { this.peakHold = -90; this.peakAge = 0; },
    draw(g, f, { w, h, dt }) {
      bg(g, w, h);
      const pad = 12, top = 14, bot = h - 24, meterW = Math.max(18, w * 0.10);
      const yDb = (db) => lerp(bot, top, dbNorm(db, -60));
      grid(g, w, h, 4, 5);
      [-60, -48, -36, -24, -12, 0].forEach((db) => {
        const y = yDb(db);
        g.strokeStyle = "rgba(255,255,255,.08)"; g.beginPath(); g.moveTo(pad, y); g.lineTo(w - pad, y); g.stroke();
        label(g, String(db), pad + meterW + 6, y + 3);
      });
      const grd = g.createLinearGradient(0, bot, 0, top);
      grd.addColorStop(0, rgba(MINT, .9)); grd.addColorStop(.72, rgba(YELLOW, .9)); grd.addColorStop(1, rgba(AMBER, .95));
      [["RMS", f.rmsDb, pad], ["PEAK", f.peakDb, pad + meterW + 18]].forEach(([name, db, x]) => {
        const y = yDb(db);
        g.fillStyle = "rgba(255,255,255,.07)"; g.fillRect(x, top, meterW, bot - top);
        g.fillStyle = grd; g.fillRect(x, y, meterW, bot - y);
        label(g, name, x - 1, h - 8);
      });
      this.peakAge += dt;
      if (f.peakDb >= this.peakHold || this.peakAge > 1.3) { this.peakHold = f.peakDb; this.peakAge = 0; }
      g.fillStyle = "rgba(255,240,220,.9)";
      g.fillRect(pad + meterW + 18, yDb(this.peakHold) - 1, meterW, 2);

      const hx = pad + meterW * 2 + 52, head = Math.max(0, -f.peakDb), risk = clamp01(1 - head / 12);
      label(g, "HEADROOM", hx, top + 4);
      g.font = "bold 18px monospace"; g.fillStyle = rgba(heat(risk), .95);
      g.fillText(`${head.toFixed(1)} dB`, hx, top + 27);
      g.font = "8px monospace";
      label(g, `CREST ${f.crestDb.toFixed(1)} dB`, hx, top + 45, rgba(MINT, .78));
      label(g, `TRANS ${f.transient.toFixed(2)}`, hx, top + 59, rgba(AMBER, .78));
      g.fillStyle = rgba(AMBER, .18); g.fillRect(hx, bot - 10, w - hx - pad, 5);
      g.fillStyle = rgba(heat(risk), .85); g.fillRect(hx, bot - 10, (w - hx - pad) * risk, 5);
    },
  };

  /* ---------- 6. Timbre Map ---------- */
  const timbreMap = {
    id: "timbre", name: "Timbre Map", port: "easy - path history",
    blurb: "A slow <b>tone-color trajectory</b>: brightness left-to-right, body-to-air vertically, tonality as point size. Shows how the song's color moves over time.",
    reset() { this.path = []; },
    draw(g, f, { w, h }) {
      bg(g, w, h);
      const pad = 18, W = w - pad * 2, H = h - pad * 2;
      grid(g, w, h, 4, 4);
      const body = clamp01((f.bass + f.lowMid) * 0.55 + f.presence * 0.15);
      const x = pad + f.brightness * W;
      const y = pad + (1 - body) * H;
      this.path.push({ x, y, b: f.brightness, t: f.tonality, o: f.onsetPulse });
      if (this.path.length > 100) this.path.shift();
      g.strokeStyle = "rgba(255,255,255,.10)";
      g.strokeRect(pad, pad, W, H);
      for (let i = 1; i < this.path.length; i++) {
        const a = i / this.path.length, p0 = this.path[i - 1], p1 = this.path[i];
        g.strokeStyle = rgba(heat(p1.b), 0.15 + a * 0.55);
        g.lineWidth = 1 + p1.o * 2;
        g.beginPath(); g.moveTo(p0.x, p0.y); g.lineTo(p1.x, p1.y); g.stroke();
      }
      const r = 3 + f.tonality * 5 + f.onsetPulse * 4;
      g.beginPath(); g.arc(x, y, r, 0, Math.PI * 2);
      g.fillStyle = rgba(heat(f.brightness), .86); g.fill();
      label(g, "DARK", pad, h - 5); label(g, "BRIGHT", w - 58, h - 5);
      label(g, "AIR", 4, pad + 3); label(g, "BODY", 4, h - pad + 3);
      label(g, `TONE ${f.tonality.toFixed(2)}`, pad, 12, rgba(MINT, .78));
    },
  };

  /* ---------- 7. Bass Foundation ---------- */
  const bassFoundation = {
    id: "foundation", name: "Bass Foundation", port: "easy - grouped meters",
    blurb: "Low-end health view: <b>sub, bass, low-mid, mud pressure, and punch</b>. Built for mixes where the right question is whether the bottom supports or swallows the track.",
    reset() {},
    draw(g, f, { w, h }) {
      bg(g, w, h);
      grid(g, w, h, 4, 4);
      const pad = 14, base = h - 24, maxH = h - 48;
      const vals = [["SUB", f.sub, MINT], ["BASS", f.bass, MINT], ["LOW MID", f.lowMid, YELLOW], ["PRES", f.presence, AMBER]];
      const readW = Math.max(86, Math.round(w * 0.31));
      const readX = w - pad - readW;
      const barW = Math.max(120, readX - pad - 10);
      const bw = (barW - 12) / vals.length;
      vals.forEach(([name, val, col], i) => {
        const x = pad + i * (bw + 4), bh = clamp01(val) * maxH;
        g.fillStyle = "rgba(255,255,255,.06)"; g.fillRect(x, base - maxH, bw, maxH);
        g.fillStyle = rgba(col, .86); g.fillRect(x, base - bh, bw, bh);
        label(g, name, x, h - 8);
      });
      const foundation = clamp01((f.sub + f.bass) * .55);
      const mud = clamp01(f.lowMid / Math.max(.08, f.presence + f.brilliance + .12));
      const punch = clamp01(f.bassFlux * 8 + f.transient * .45);
      label(g, "FOUNDATION", readX, 18);
      g.fillStyle = rgba(MINT, .18); g.fillRect(readX, 28, w - readX - pad, 6);
      g.fillStyle = rgba(MINT, .86); g.fillRect(readX, 28, (w - readX - pad) * foundation, 6);
      label(g, `MUD ${mud.toFixed(2)}`, readX, 52, rgba(heat(mud), .88));
      g.fillStyle = rgba(heat(mud), .18); g.fillRect(readX, 59, w - readX - pad, 6);
      g.fillStyle = rgba(heat(mud), .86); g.fillRect(readX, 59, (w - readX - pad) * mud, 6);
      label(g, `PUNCH ${punch.toFixed(2)}`, readX, 83, rgba(AMBER, .88));
      g.fillStyle = rgba(AMBER, .18); g.fillRect(readX, 90, w - readX - pad, 6);
      g.fillStyle = rgba(AMBER, .86); g.fillRect(readX, 90, (w - readX - pad) * punch, 6);
    },
  };

  global.PomoAmpStyles = [waveTrace, bandprint, spectrogram, grooveRail, headroom, timbreMap, bassFoundation];
})(window);
