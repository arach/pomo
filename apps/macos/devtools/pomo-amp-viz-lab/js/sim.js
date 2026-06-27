/* sim.js — PomoAmpVizData simulator.
 *
 * Goal: produce frames whose SHAPE and DERIVED METRICS match what the native
 * PomoAmp pipeline emits, so a style that looks good here behaves the same on real
 * audio. The metric derivation below is a faithful JS port of
 *   apps/macos/Sources/PomoShared/PomoAmp/PomoAmpVizAnalyzer.swift
 * (spectralMetrics + onset detector). Only the *source* signal (bands / waveform
 * / rms / peak / low / mid / high) is synthesized here; everything downstream
 * (sub..brilliance, centroid, brightness, flux, onsetPulse, drop, transient…)
 * is computed exactly the way the analyzer computes it from those inputs.
 *
 * Field reference (PomoAmpVizData), ranges as emitted today:
 *   progress 0..1 · rms/peak 0..1 · rmsDb/peakDb -90..0 · crestDb 0..~ · transient 0..1
 *   low/mid/high 0..1 · sub/bass/lowMid/presence/brilliance 0..1
 *   centroidHz/bandwidthHz/rolloff85Hz Hz · brightness 0..1 (log-norm centroid)
 *   tonality 0..1 · flux/bassFlux ~0..0.3 · onsetScore 0..3 · onsetPulse 0..1 · onset bool
 *   drop 0..1 · bands[24] 0..1 · waveform[32] -1..1
 *   NOTE: bpm and the beat/bar fields are NOT computed by PomoAmp today (it emits 0 / 1). The lab
 *   fills them in synthetic mode for study, but styles that must ship today should
 *   rely on onsetPulse / rms / bands, not on beat phase. */
(function (global) {
  "use strict";

  const BANDS = 24;
  const WAVE = 32;
  const MIN_HZ = 45, MAX_HZ = 18000;
  const FPS = 30;

  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
  const lerp = (a, b, t) => a + (b - a) * t;
  const fract = (x) => x - Math.floor(x);
  const log1p = (x) => Math.log(1 + x);

  function bandCenters(count) {
    const lo = Math.log(MIN_HZ), hi = Math.log(MAX_HZ), out = [];
    for (let i = 0; i < count; i++) out.push(Math.exp(lerp(lo, hi, i / Math.max(1, count - 1))));
    return out;
  }
  const CENTERS = bandCenters(BANDS);

  const decibels = (v) => Math.max(-90, 20 * Math.log10(Math.max(1e-6, v)));
  function logNormalize(v, min, max) {
    const a = Math.log(min), b = Math.log(max);
    return clamp((Math.log(Math.max(v, 1e-6)) - a) / (b - a), 0, 1);
  }
  function averageRange(vals, lo, hi) {
    lo = Math.max(0, Math.min(vals.length, lo));
    hi = Math.max(lo, Math.min(vals.length, hi));
    if (lo >= hi) return 0;
    let t = 0; for (let i = lo; i < hi; i++) t += vals[i];
    return t / (hi - lo);
  }
  function positiveFlux(cur, prev) {
    if (!cur.length || cur.length !== prev.length) return 0;
    let t = 0; for (let i = 0; i < cur.length; i++) t += Math.max(0, cur[i] - prev[i]);
    return t / cur.length;
  }

  /* ---- faithful port of PomoAmpVizAnalyzer onset/spectral state ---- */
  function freshAnalyzerState() {
    return { prevLog: [], prevBassLog: [], fluxMean: 0, fluxDev: 0, bassFluxMean: 0,
             onsetPulse: 0, lastOnset: -Infinity, last: 0 };
  }

  function deriveMetrics(st, bands, rms, peak, hostTime) {
    const m = {};
    m.rmsDb = decibels(rms);
    m.peakDb = decibels(peak);
    m.crestDb = Math.max(0, m.peakDb - m.rmsDb);
    m.transient = clamp((m.crestDb - 6) / 12, 0, 1);
    m.sub = averageRange(bands, 0, 2);
    m.bass = averageRange(bands, 2, 6);
    m.lowMid = averageRange(bands, 6, 9);
    m.presence = averageRange(bands, 15, 20);
    m.brilliance = averageRange(bands, 20, bands.length);

    const mags = bands.map((b) => Math.max(0, b));
    const powers = mags.map((b) => b * b);
    const magTotal = mags.reduce((a, b) => a + b, 0);
    const powTotal = powers.reduce((a, b) => a + b, 0);
    m.centroidHz = 0; m.bandwidthHz = 0; m.brightness = 0; m.rolloff85Hz = 0; m.tonality = 0;
    if (magTotal > 1e-6) {
      let c = 0; for (let i = 0; i < BANDS; i++) c += CENTERS[i] * mags[i];
      m.centroidHz = c / magTotal;
      let spread = 0;
      for (let i = 0; i < BANDS; i++) { const d = CENTERS[i] - m.centroidHz; spread += mags[i] * d * d; }
      m.bandwidthHz = Math.sqrt(Math.max(0, spread / magTotal));
      m.brightness = logNormalize(m.centroidHz, 80, 12000);
    }
    if (powTotal > 1e-6) {
      let cum = 0;
      for (let i = 0; i < BANDS; i++) { cum += powers[i]; if (cum >= powTotal * 0.85) { m.rolloff85Hz = CENTERS[Math.min(i, BANDS - 1)]; break; } }
      const eps = 1e-6;
      const arith = powers.reduce((a, b) => a + b + eps, 0) / BANDS;
      const geo = Math.exp(powers.reduce((a, b) => a + Math.log(b + eps), 0) / BANDS);
      m.tonality = clamp(1 - geo / Math.max(arith, eps), 0, 1);
    }

    const logBands = bands.map((b) => log1p(b * 12));
    const bassLog = logBands.slice(0, 6);
    const reset = st.prevLog.length !== logBands.length;
    const dt = st.last > 0 ? clamp(hostTime - st.last, 1 / 120, 0.25) : 1 / FPS;
    if (reset) {
      st.prevLog = logBands; st.prevBassLog = bassLog; st.last = hostTime; st.onsetPulse = 0;
      m.flux = 0; m.bassFlux = 0; m.onsetScore = 0; m.onset = false; m.onsetPulse = 0;
      return m;
    }
    m.flux = positiveFlux(logBands, st.prevLog);
    m.bassFlux = positiveFlux(bassLog, st.prevBassLog);
    st.prevLog = logBands; st.prevBassLog = bassLog; st.last = hostTime;

    const a = 1 - Math.exp(-dt / 1.0);
    st.fluxMean += (m.flux - st.fluxMean) * a;
    st.fluxDev += (Math.abs(m.flux - st.fluxMean) - st.fluxDev) * a;
    st.bassFluxMean += (m.bassFlux - st.bassFluxMean) * a;

    const threshold = st.fluxMean + st.fluxDev * 1.35 + 0.018;
    m.onsetScore = clamp(Math.max(0, (m.flux - threshold) / Math.max(0.018, st.fluxDev + 0.006)), 0, 3);
    const bassKick = m.bassFlux > Math.max(0.035, st.bassFluxMean * 1.55);
    m.onset = m.onsetScore > 1.0 && bassKick && hostTime - st.lastOnset > 0.09;
    if (m.onset) { st.onsetPulse = 1; st.lastOnset = hostTime; }
    else { st.onsetPulse *= Math.exp(-dt / 0.12); }
    m.onsetPulse = clamp(st.onsetPulse, 0, 1);
    return m;
  }

  function assemble(scope, m, t) {
    const drop = Math.max(clamp(Math.max(0, scope.peak - scope.rms) * 1.4, 0, 1), m.onsetPulse * 0.86, m.bassFlux * 0.66);
    return {
      version: 1, frame: Math.floor(t * FPS), source: scope.source || "sim", sourceError: null,
      latencyMs: scope.latencyMs || 0, hostTime: t, mediaTime: scope.mediaTime || 0,
      duration: scope.duration || 0, progress: scope.progress || 0, playbackRate: 1, isPlaying: scope.isPlaying !== false,
      bpm: scope.bpm || 0, beatIndex: scope.beatIndex || 0, beatPhase: scope.beatPhase ?? 1,
      barIndex: scope.barIndex || 0, barPhase: scope.barPhase ?? 1,
      drop, rms: scope.rms, rmsDb: m.rmsDb, peak: scope.peak, peakDb: m.peakDb, crestDb: m.crestDb,
      transient: m.transient, low: scope.low, mid: scope.mid, high: scope.high,
      sub: m.sub, bass: m.bass, lowMid: m.lowMid, presence: m.presence, brilliance: m.brilliance,
      centroidHz: m.centroidHz, bandwidthHz: m.bandwidthHz, brightness: m.brightness,
      rolloff85Hz: m.rolloff85Hz, tonality: m.tonality, flux: m.flux, bassFlux: m.bassFlux,
      onsetScore: m.onsetScore, onsetPulse: m.onsetPulse, onset: m.onset,
      bands: scope.bands, waveform: scope.waveform,
    };
  }

  /* ---------- synthetic signal scenarios ---------- */
  // Each scenario returns a raw "scope" {bands,waveform,rms,peak,low,mid,high,...meta}
  // for a given absolute time t and params; deriveMetrics() finishes the frame.

  // simple deterministic value-noise so motion is smooth & reproducible
  function vnoise(x) {
    const i = Math.floor(x), f = fract(x);
    const h = (n) => fract(Math.sin(n * 127.1) * 43758.5453);
    const u = f * f * (3 - 2 * f);
    return lerp(h(i), h(i + 1), u) * 2 - 1;
  }

  function buildWaveform(parts, amp) {
    const w = new Array(WAVE);
    for (let i = 0; i < WAVE; i++) {
      const x = i / WAVE;
      let s = 0;
      for (const p of parts) s += Math.sin(2 * Math.PI * p.f * x + p.ph) * p.a;
      w[i] = clamp(s * amp, -1, 1);
    }
    return w;
  }

  function rmsPeak(w) {
    let sum = 0, pk = 0;
    for (const v of w) { sum += v * v; pk = Math.max(pk, Math.abs(v)); }
    return { rms: Math.sqrt(sum / w.length), peak: pk };
  }

  // distribute a blob of energy around a band index
  function addBlob(bands, center, width, amp) {
    for (let i = 0; i < bands.length; i++) {
      const d = (i - center) / width;
      bands[i] += amp * Math.exp(-d * d);
    }
  }

  function makeScenarios() {
    return {
      house: {
        name: "Four-on-floor (house)",
        gen(t, p) {
          const beatLen = 60 / p.bpm;
          const bp = t / beatLen, beat = Math.floor(bp), phase = fract(bp);
          const bars = Math.floor(beat / 4);
          const kick = Math.exp(-phase * 11) * p.gain;                    // every beat
          const hat = (fract(bp + 0.5) < 0.5 ? Math.exp(-fract(bp + 0.5) * 26) : 0) * 0.5 * p.gain;
          const bass = Math.exp(-phase * 5) * (0.6 + 0.3 * Math.sin(bars)) * p.gain;
          const noteIdx = [0, 3, 5, 7][beat % 4];
          const lead = (0.35 + 0.25 * vnoise(t * 0.7)) * p.gain;
          const bands = new Array(BANDS).fill(0).map(() => 0.02 + 0.02 * Math.random());
          addBlob(bands, 1.2, 1.4, kick * 0.95);
          addBlob(bands, 4, 2.2, bass * 0.8);
          addBlob(bands, 9 + noteIdx, 1.6, lead * 0.7);
          addBlob(bands, 12 + noteIdx, 1.2, lead * 0.4);
          addBlob(bands, 21, 2.5, hat * 0.6);
          for (let i = 0; i < BANDS; i++) bands[i] = clamp(bands[i], 0, 1);
          const w = buildWaveform([
            { f: 1.0, a: kick * 0.9, ph: phase * 6 },
            { f: 4 + noteIdx, a: lead * 0.5, ph: t * 2 },
            { f: 9 + noteIdx, a: lead * 0.3, ph: t * 3 },
            { f: 22, a: hat * 0.25, ph: t * 30 },
          ], 1.0);
          const { rms, peak } = rmsPeak(w);
          return scope(bands, w, rms, Math.min(1, peak + kick * 0.25), t, p, { bp, beat, bars });
        },
      },

      drop: {
        name: "Build + Drop",
        gen(t, p) {
          const beatLen = 60 / p.bpm;
          const cycle = 32 * beatLen;                                     // 8-bar loop
          const c = fract(t / cycle);                                     // 0..1 within loop
          const inDrop = c > 0.5;
          const buildN = clamp((c - 0.05) / 0.45, 0, 1);                  // riser 0..1
          const bp = t / beatLen, phase = fract(bp), beat = Math.floor(bp);
          const bands = new Array(BANDS).fill(0).map(() => 0.02);
          let kick = 0, energy = 0;
          if (!inDrop) {
            // riser: rising filtered noise + accelerating snare roll
            const rollRate = lerp(2, 16, buildN);
            const roll = Math.exp(-fract(t * rollRate) * 6) * buildN;
            addBlob(bands, lerp(6, 22, buildN), lerp(6, 2, buildN), 0.5 * buildN * p.gain);
            addBlob(bands, 16, 3, roll * 0.7 * p.gain);
            energy = 0.2 + buildN * 0.5;
            if (c > 0.47) energy *= 1 - (c - 0.47) / 0.03;                // pre-drop suck-out
          } else {
            const dc = (c - 0.5) / 0.5;
            kick = Math.exp(-phase * 9) * p.gain;
            const bass = Math.exp(-phase * 4) * p.gain;
            addBlob(bands, 1.3, 1.6, kick * 1.0);
            addBlob(bands, 4, 2.4, bass * 0.9);
            addBlob(bands, 10 + (beat % 5), 1.8, (0.5 + 0.3 * vnoise(t)) * p.gain);
            addBlob(bands, 21, 2.5, (fract(bp + 0.5) < 0.4 ? 0.5 : 0) * p.gain);
            energy = 0.85 - dc * 0.1;
          }
          for (let i = 0; i < BANDS; i++) bands[i] = clamp(bands[i] + 0.02 * Math.random(), 0, 1);
          const w = buildWaveform([
            { f: 1, a: kick * 0.9, ph: phase * 6 },
            { f: lerp(8, 20, buildN), a: (inDrop ? 0.3 : buildN * 0.5), ph: t * 5 },
            { f: 14, a: 0.25 * energy, ph: t * 9 },
          ], inDrop ? 1.0 : 0.8);
          const { rms, peak } = rmsPeak(w);
          return scope(bands, w, rms * (0.6 + energy * 0.6), Math.min(1, peak + kick * 0.3), t, p, { bp, beat, bars: Math.floor(beat / 4) });
        },
      },

      ambient: {
        name: "Ambient pad (low transient)",
        gen(t, p) {
          const bands = new Array(BANDS).fill(0);
          for (let i = 0; i < BANDS; i++) {
            const swell = 0.5 + 0.5 * Math.sin(t * 0.25 + i * 0.5);
            bands[i] = clamp((0.12 + 0.4 * Math.exp(-Math.pow((i - 7 - 3 * Math.sin(t * 0.15)) / 5, 2))) * swell * p.gain, 0, 1);
          }
          const w = buildWaveform([
            { f: 2, a: 0.5, ph: t * 0.8 },
            { f: 3, a: 0.3, ph: t * 1.1 },
            { f: 5, a: 0.18, ph: t * 0.6 },
          ], (0.5 + 0.3 * Math.sin(t * 0.3)) * p.gain);
          const { rms, peak } = rmsPeak(w);
          return scope(bands, w, rms, peak, t, p, { bp: t / (60 / p.bpm), beat: 0, bars: 0 });
        },
      },

      breaks: {
        name: "Breakbeat (high crest)",
        gen(t, p) {
          const beatLen = 60 / p.bpm;
          // syncopated amen-ish pattern: hits at irregular 16th positions
          const pattern = [1, 0, 0.4, 0, 0.8, 0, 0, 0.5, 1, 0, 0.3, 0.6, 0, 0.4, 0.7, 0];
          const sixteenth = t / (beatLen / 4);
          const idx = Math.floor(sixteenth) % 16, ph = fract(sixteenth);
          const hit = pattern[idx] * Math.exp(-ph * 14) * p.gain;
          const snare = (idx === 4 || idx === 12) ? Math.exp(-ph * 10) * p.gain : 0;
          const bands = new Array(BANDS).fill(0).map(() => 0.02);
          addBlob(bands, 1.5, 1.6, hit * 0.9);
          addBlob(bands, 8, 3, snare * 0.7);
          addBlob(bands, 18, 4, (snare + hit * 0.4) * 0.6);
          addBlob(bands, 22, 2, hit * 0.3);
          for (let i = 0; i < BANDS; i++) bands[i] = clamp(bands[i] + 0.02 * Math.random(), 0, 1);
          const w = buildWaveform([
            { f: 1.5, a: hit * 0.8, ph: ph * 7 },
            { f: 9, a: snare * 0.6, ph: t * 11 },
            { f: 20, a: (hit + snare) * 0.3, ph: t * 25 },
          ], 1.0);
          const { rms, peak } = rmsPeak(w);
          return scope(bands, w, rms * 0.8, Math.min(1, peak + hit * 0.4), t, p, { bp: sixteenth / 4, beat: Math.floor(sixteenth / 4), bars: 0 });
        },
      },

      sweep: {
        name: "Sine sweep (centroid demo)",
        gen(t, p) {
          const u = fract(t / 6);                                         // 6s low→high sweep
          const band = u * (BANDS - 1);
          const bands = new Array(BANDS).fill(0).map((_, i) => clamp(0.9 * Math.exp(-Math.pow((i - band) / 1.1, 2)) * p.gain, 0, 1));
          const freq = lerp(1, 26, u);
          const w = buildWaveform([{ f: freq, a: 0.85, ph: t * 2 }], p.gain);
          const { rms, peak } = rmsPeak(w);
          return scope(bands, w, rms, peak, t, p, { bp: 0, beat: 0, bars: 0 });
        },
      },
    };
  }

  function scope(bands, waveform, rms, peak, t, p, meta) {
    const low = clamp(averageRange(bands, 0, 7) * 1.5, 0, 1);
    const mid = clamp(averageRange(bands, 7, 16) * 1.5, 0, 1);
    const high = clamp(averageRange(bands, 16, BANDS) * 1.7, 0, 1);
    const beatLen = 60 / p.bpm;
    return {
      source: "sim", bands, waveform, rms: clamp(rms, 0, 1), peak: clamp(peak, 0, 1), low, mid, high,
      isPlaying: true, bpm: p.bpm, mediaTime: t, duration: 213, progress: fract(t / 213),
      beatIndex: meta.beat || 0, beatPhase: fract((meta.bp || 0)), barIndex: meta.bars || 0,
      barPhase: fract((meta.bp || 0) / 4),
    };
  }

  /* ---------- Simulator wrapper ---------- */
  class Simulator {
    constructor() {
      this.scenarios = makeScenarios();
      this.key = "house";
      this.params = { bpm: 124, gain: 1.0 };
      this.state = freshAnalyzerState();
      this.frozen = null;
    }
    setScenario(k) { if (this.scenarios[k]) { this.key = k; this.state = freshAnalyzerState(); } }
    list() { return Object.entries(this.scenarios).map(([k, v]) => ({ key: k, name: v.name })); }
    frame(t) {
      const sc = this.scenarios[this.key].gen(t, this.params);
      const m = deriveMetrics(this.state, sc.bands, sc.rms, sc.peak, t);
      return assemble(sc, m, t);
    }
  }

  /* ---------- Live input (mic or dropped audio file) ----------
   * Feeds real AnalyserNode data through the SAME deriveMetrics() port, so the
   * lab can study styles against real audio without any native build. */
  class LiveInput {
    constructor() {
      this.ctx = null; this.analyser = null; this.freq = null; this.time = null;
      this.source = null; this.audioEl = null; this.kind = null;
      this.state = freshAnalyzerState(); this.t0 = 0;
    }
    get active() { return !!this.analyser; }
    async _ensureCtx() {
      if (!this.ctx) {
        this.ctx = new (global.AudioContext || global.webkitAudioContext)();
        this.analyser = this.ctx.createAnalyser();
        this.analyser.fftSize = 1024;
        this.analyser.smoothingTimeConstant = 0.6;
        this.freq = new Uint8Array(this.analyser.frequencyBinCount);
        this.time = new Uint8Array(this.analyser.fftSize);
      }
      if (this.ctx.state === "suspended") await this.ctx.resume();
    }
    async useMic() {
      await this._ensureCtx();
      const stream = await global.navigator.mediaDevices.getUserMedia({ audio: true });
      this._connect(this.ctx.createMediaStreamSource(stream), "mic");
    }
    async useFile(file) {
      await this._ensureCtx();
      const el = new global.Audio();
      el.src = URL.createObjectURL(file); el.loop = true; el.crossOrigin = "anonymous";
      await el.play().catch(() => {});
      this.audioEl = el;
      this._connect(this.ctx.createMediaElementSource(el), "file");
      this.analyser.connect(this.ctx.destination); // route file audio to speakers
    }
    _connect(node, kind) {
      if (this.source) try { this.source.disconnect(); } catch (e) {}
      this.source = node; this.kind = kind;
      node.connect(this.analyser);
      this.state = freshAnalyzerState();
    }
    stop() {
      try { this.source && this.source.disconnect(); } catch (e) {}
      if (this.audioEl) { this.audioEl.pause(); this.audioEl = null; }
      this.analyser = null; this.source = null; this.kind = null; this.ctx = null;
    }
    frame(t) {
      if (!this.analyser) return null;
      this.analyser.getByteFrequencyData(this.freq);
      this.analyser.getByteTimeDomainData(this.time);
      // fold FFT bins into 24 log-spaced bands
      const bands = new Array(BANDS).fill(0);
      const n = this.freq.length, nyq = this.ctx.sampleRate / 2;
      for (let i = 0; i < BANDS; i++) {
        const f0 = CENTERS[i] / Math.SQRT2, f1 = CENTERS[i] * Math.SQRT2;
        let lo = Math.max(0, Math.floor((f0 / nyq) * n)), hi = Math.min(n - 1, Math.ceil((f1 / nyq) * n));
        if (hi < lo) hi = lo; let s = 0, c = 0;
        for (let k = lo; k <= hi; k++) { s += this.freq[k]; c++; }
        bands[i] = clamp((c ? s / c : 0) / 255, 0, 1);
      }
      const waveform = new Array(WAVE);
      const step = this.time.length / WAVE;
      let pk = 0, sq = 0;
      for (let i = 0; i < WAVE; i++) { const v = (this.time[Math.floor(i * step)] - 128) / 128; waveform[i] = clamp(v, -1, 1); pk = Math.max(pk, Math.abs(v)); sq += v * v; }
      const rms = Math.sqrt(sq / WAVE);
      const sc = {
        source: "webAudio", bands, waveform, rms: clamp(rms, 0, 1), peak: clamp(pk, 0, 1),
        low: clamp(averageRange(bands, 0, 7) * 1.5, 0, 1), mid: clamp(averageRange(bands, 7, 16) * 1.5, 0, 1),
        high: clamp(averageRange(bands, 16, BANDS) * 1.7, 0, 1),
        isPlaying: true, bpm: 0, mediaTime: this.audioEl ? this.audioEl.currentTime : t,
        duration: this.audioEl ? this.audioEl.duration || 0 : 0,
        progress: this.audioEl && this.audioEl.duration ? this.audioEl.currentTime / this.audioEl.duration : 0,
        beatIndex: 0, beatPhase: 1, barIndex: 0, barPhase: 1,
      };
      const m = deriveMetrics(this.state, bands, sc.rms, sc.peak, t);
      return assemble(sc, m, t);
    }
  }

  global.PomoAmpSim = { Simulator, LiveInput, BANDS, WAVE, CENTERS, clamp, lerp };
})(window);
