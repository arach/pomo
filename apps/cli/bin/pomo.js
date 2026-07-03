#!/usr/bin/env node
// pomo — control and install the Pomo macOS HUD timer.
//
// Commands are sent fire-and-forget over the `pomo://` URL scheme (via `open`);
// `status` reads the JSON state file the app writes on every tick; `install`
// pulls the latest .dmg from GitHub releases and drops Pomo.app in /Applications.
//
// Zero dependencies — Node 18+ built-ins only. macOS only (it drives `open`,
// `hdiutil`, etc.).

import { execFileSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  unwatchFile,
  watch,
  watchFile,
  writeFileSync,
} from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

const REPO = 'arach/pomo';
const STATE_FILE = join(homedir(), 'Library', 'Application Support', 'Pomo', 'state.json');
const TUI_PREFS_FILE = join(homedir(), 'Library', 'Application Support', 'Pomo', 'cli-tui.json');

const argv = process.argv.slice(2);
const cmd = (argv[0] || '').toLowerCase();

// ─── helpers ────────────────────────────────────────────────────────────────

function die(msg) {
  console.error(`pomo: ${msg}`);
  process.exit(1);
}

function requireMac() {
  if (process.platform !== 'darwin') die('this CLI only works on macOS.');
}

/**
 * Which Pomo.app should handle a `pomo://` command. With many stale bundles
 * registered (old worktrees, mounted DMGs, cached builds), bare `open pomo://`
 * routes unpredictably to "some older version". So:
 *   1. honour an explicit POMO_APP env override, else
 *   2. when this CLI lives inside the repo, prefer its sibling dev build, so
 *      `pomo` drives the copy you're hacking on — not whatever LaunchServices
 *      happens to pick.
 * Returns null for a plain npm install (no sibling app) → default routing.
 */
function targetApp() {
  if (process.env.POMO_APP) return process.env.POMO_APP;
  const devApp = join(fileURLToPath(import.meta.url), '../../../macos/dist/Pomo.app');
  return existsSync(devApp) ? devApp : null;
}

/** Fire a pomo:// command at the app via `open`. */
function send(path, { soft = false } = {}) {
  requireMac();
  const url = `pomo://${path}`;
  const app = targetApp();
  try {
    execFileSync('open', app ? ['-a', app, url] : [url], { stdio: 'ignore' });
    return true;
  } catch {
    if (soft) return false;
    die(`couldn't reach Pomo. Is it installed? Try: pomo install`);
  }
}

/** Build a query string from {k: v} pairs, skipping null/undefined. */
function query(pairs) {
  const parts = Object.entries(pairs)
    .filter(([, v]) => v !== undefined && v !== null && v !== '')
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`);
  return parts.length ? `?${parts.join('&')}` : '';
}

/** Pull a `--flag value` (or `--flag=value`) out of args; returns the value or undefined. */
function takeFlag(args, name) {
  const eq = args.find((a) => a.startsWith(`--${name}=`));
  if (eq) return eq.slice(name.length + 3);
  const i = args.indexOf(`--${name}`);
  if (i >= 0 && i + 1 < args.length) return args[i + 1];
  return undefined;
}

function hasFlag(args, name) {
  return args.includes(`--${name}`);
}

function readState() {
  if (!existsSync(STATE_FILE)) {
    die(`no state file at ${STATE_FILE}\n      Pomo may not be installed or hasn't run yet. Try: pomo install`);
  }
  try {
    return JSON.parse(readFileSync(STATE_FILE, 'utf8'));
  } catch {
    die('state file is unreadable.');
  }
}

// ─── status ───────────────────────────────────────────────────────────────

function printStatus(args) {
  const s = readState();
  if (hasFlag(args, 'json')) {
    console.log(JSON.stringify(s, null, 2));
    return;
  }
  const dot = s.phase === 'running' ? '●' : s.phase === 'paused' ? '❚❚' : '○';
  const phase = s.phase === 'idle' ? 'idle' : s.phase;
  console.log(`${dot} ${s.sessionType} · ${s.clock} (${phase})`);
  if (s.intent) console.log(`  intent  ${s.intent}`);

  let audio = '—';
  if (s.audioURL) {
    const fav = (s.favorites || []).find((f) => f.url === s.audioURL);
    const label = fav ? fav.title : s.audioURL;
    audio = `${s.audioPlaying ? '▶' : '⏸'} ${label}`;
  }
  console.log(`  audio   ${audio}`);
  console.log(`  today   ${s.focusToday ?? 0} focus · streak ${s.streakDays ?? 0}d · ${s.focusTotal ?? 0} total`);
  console.log(`  hud     ${s.hudVisible ? 'visible' : 'hidden'} · face ${s.watchface}`);

  const favs = s.favorites || [];
  const sessionAudio = s.sessionAudioURLs || {};
  const sessionLabels = [
    ['focus', 'focus'],
    ['shortBreak', 'break'],
    ['longBreak', 'long'],
  ];
  const assigned = sessionLabels.filter(([key]) => sessionAudio[key]);
  if (assigned.length) {
    console.log('  session audio');
    assigned.forEach(([key, label]) => {
      const fav = favs.find((f) => f.url === sessionAudio[key]);
      console.log(`    ${label.padEnd(5)} ${fav ? fav.title : sessionAudio[key]}`);
    });
  }
  if (favs.length) {
    console.log('  favorites');
    favs.forEach((f, i) => console.log(`    ${i + 1}. ${f.title}`));
  }
}

// ─── TUI (`pomo` in a TTY, or `pomo tui`) ───────────────────────────────────

const TUI_THEMES = {
  ember: {
    label: 'Ember',
    mark: '◐',
    tagline: 'one task, one stretch',
    accent: '38;5;215',
    ok: '38;5;215',
    warn: '38;5;180',
    text: '38;5;230',
    soft: '38;5;180',
    mute: '38;5;137',
    dim: '38;5;95',
    track: '38;5;94',
    glow: '38;5;222',
    border: '38;5;130',
    canvas: 52,
    margin: 58,
    card: 235,
    halo: 58,
    shadow: 232,
    bg: [52, 58, 237],
    bgStyle: 'ember',
    fill: '━',
    empty: '─',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'This stretch belongs to one thing.', paused: 'Paused. The desk can wait.', idle: 'Name the task, then begin.' },
      shortbreak: { running: 'Look away from the glass.', paused: 'Break on hold.', idle: 'Breathe before the next round.' },
      longbreak: { running: 'Move, water, air — you earned this.', paused: 'Rest can wait too.', idle: 'A real pause, not a tab switch.' },
    },
  },
  minimal: {
    label: 'Minimal',
    mark: '·',
    tagline: 'quiet clarity',
    accent: '38;5;252',
    ok: '38;5;252',
    warn: '38;5;245',
    text: '38;5;254',
    soft: '38;5;247',
    mute: '38;5;244',
    dim: '38;5;240',
    track: '38;5;240',
    glow: '38;5;255',
    border: '38;5;244',
    canvas: 232,
    margin: 234,
    card: 236,
    halo: 235,
    shadow: 232,
    bg: [234, 235, 237],
    bgStyle: 'mist',
    fill: '━',
    empty: '─',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'Nothing else needs you right now.', paused: 'Stillness is allowed.', idle: 'Start when the task is clear.' },
      shortbreak: { running: 'Let your eyes rest.', paused: '—', idle: 'Short reset.' },
      longbreak: { running: 'Step out of the flow for a minute.', paused: '—', idle: 'Long break awaits.' },
    },
  },
  terminal: {
    label: 'Terminal',
    mark: '>',
    tagline: 'green phosphor calm',
    accent: '38;5;82',
    ok: '38;5;82',
    warn: '38;5;190',
    text: '38;5;120',
    soft: '38;5;65',
    mute: '38;5;65',
    dim: '38;5;22',
    track: '38;5;22',
    glow: '38;5;154',
    border: '38;5;28',
    canvas: 16,
    margin: 22,
    card: 232,
    halo: 22,
    shadow: 16,
    bg: [16, 233, 235],
    bgStyle: 'flat',
    fill: '━',
    empty: '─',
    frame: ['┌', '┐', '└', '┘', '─', '│'],
    whispers: {
      focus: { running: '> focus_session --now', paused: '> session paused', idle: '> awaiting intent' },
      shortbreak: { running: '> break --short', paused: '> break paused', idle: '> break ready' },
      longbreak: { running: '> break --long', paused: '> break paused', idle: '> break ready' },
    },
  },
  neon: {
    label: 'Neon',
    mark: '◆',
    tagline: 'electric hours',
    accent: '38;5;201',
    ok: '38;5;46',
    warn: '38;5;226',
    text: '38;5;225',
    soft: '38;5;177',
    mute: '38;5;103',
    dim: '38;5;60',
    track: '38;5;54',
    glow: '38;5;213',
    border: '38;5;129',
    canvas: 17,
    margin: 54,
    card: 235,
    halo: 53,
    shadow: 16,
    bg: [53, 54, 235],
    bgStyle: 'neon',
    fill: '━',
    empty: '─',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'Night shift. One bright thread.', paused: 'Lights on hold.', idle: 'Plug in a purpose.' },
      shortbreak: { running: 'Cool the tubes.', paused: '—', idle: 'Quick flicker.' },
      longbreak: { running: 'Power down the mainframe.', paused: '—', idle: 'Extended cooldown.' },
    },
  },
  retro: {
    label: 'Retro',
    mark: '▮',
    tagline: 'lcd afternoon',
    accent: '38;5;214',
    ok: '38;5;214',
    warn: '38;5;203',
    text: '38;5;223',
    soft: '38;5;180',
    mute: '38;5;137',
    dim: '38;5;94',
    track: '38;5;94',
    glow: '38;5;223',
    border: '38;5;172',
    canvas: 52,
    margin: 58,
    card: 94,
    halo: 58,
    shadow: 52,
    bg: [52, 53, 54],
    bgStyle: 'lcd',
    fill: '▰',
    empty: '▱',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'COUNTDOWN ENGAGED', paused: 'HOLD', idle: 'SET TASK' },
      shortbreak: { running: 'COOL DOWN', paused: 'HOLD', idle: 'READY' },
      longbreak: { running: 'EXTENDED COOL', paused: 'HOLD', idle: 'READY' },
    },
  },
  blueprint: {
    label: 'Blueprint',
    mark: '◎',
    tagline: 'measured attention',
    accent: '38;5;45',
    ok: '38;5;51',
    warn: '38;5;117',
    text: '38;5;159',
    soft: '38;5;73',
    mute: '38;5;67',
    dim: '38;5;24',
    track: '38;5;24',
    glow: '38;5;45',
    border: '38;5;31',
    canvas: 17,
    margin: 18,
    card: 19,
    halo: 18,
    shadow: 16,
    bg: [17, 18, 19],
    bgStyle: 'grid',
    fill: '━',
    empty: '─',
    frame: ['┌', '┐', '└', '┘', '─', '│'],
    whispers: {
      focus: { running: 'Tolerance: one task at a time.', paused: 'Work halted — note position.', idle: 'Draft the intent line.' },
      shortbreak: { running: 'Clearance for short interval.', paused: '—', idle: 'Interval pending.' },
      longbreak: { running: 'Extended clearance granted.', paused: '—', idle: 'Long interval pending.' },
    },
  },
  warm: {
    label: 'Warm',
    mark: '▮',
    tagline: 'maroon ticket glow',
    accent: '38;5;220',
    ok: '38;5;214',
    warn: '38;5;203',
    text: '38;5;223',
    soft: '38;5;180',
    mute: '38;5;137',
    dim: '38;5;130',
    track: '38;5;94',
    glow: '38;5;228',
    border: '38;5;172',
    canvas: 52,
    margin: 58,
    card: 94,
    halo: 58,
    shadow: 52,
    bg: [52, 58, 94],
    bgStyle: 'lcd',
    fill: '▰',
    empty: '▱',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'Warm stretch. One thing.', paused: 'Held.', idle: 'Name the task.' },
      shortbreak: { running: 'Look away.', paused: '—', idle: 'Breathe.' },
      longbreak: { running: 'Earned rest.', paused: '—', idle: 'Long pause.' },
    },
  },
  cool: {
    label: 'Cool',
    mark: '◇',
    tagline: 'polar lcd calm',
    accent: '38;5;117',
    ok: '38;5;51',
    warn: '38;5;111',
    text: '38;5;159',
    soft: '38;5;73',
    mute: '38;5;67',
    dim: '38;5;24',
    track: '38;5;24',
    glow: '38;5;45',
    border: '38;5;31',
    canvas: 17,
    margin: 18,
    card: 19,
    halo: 18,
    shadow: 16,
    bg: [17, 18, 19],
    bgStyle: 'grid',
    fill: '━',
    empty: '─',
    frame: ['┌', '┐', '└', '┘', '─', '│'],
    whispers: {
      focus: { running: 'Cold focus. One thread.', paused: 'Paused.', idle: 'Set intent.' },
      shortbreak: { running: 'Eyes off glass.', paused: '—', idle: 'Short reset.' },
      longbreak: { running: 'Extended cool-down.', paused: '—', idle: 'Long break.' },
    },
  },
  chronograph: {
    label: 'Chronograph',
    mark: '◷',
    tagline: 'precise intervals',
    accent: '38;5;252',
    ok: '38;5;149',
    warn: '38;5;220',
    text: '38;5;253',
    soft: '38;5;248',
    mute: '38;5;245',
    dim: '38;5;238',
    track: '38;5;240',
    glow: '38;5;255',
    border: '38;5;245',
    canvas: 235,
    margin: 236,
    card: 238,
    halo: 236,
    shadow: 232,
    bg: [235, 236, 238],
    bgStyle: 'ticks',
    fill: '━',
    empty: '─',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'Hand moving. Stay with it.', paused: 'Crown pulled.', idle: 'Wind the session.' },
      shortbreak: { running: 'Sub-dial rest.', paused: '—', idle: 'Brief interval.' },
      longbreak: { running: 'Main spring unwind.', paused: '—', idle: 'Long interval.' },
    },
  },
  amber: {
    label: 'Amber',
    mark: '▲',
    tagline: 'p3 phosphor warmth',
    accent: '38;5;214',
    ok: '38;5;214',
    warn: '38;5;208',
    text: '38;5;223',
    soft: '38;5;180',
    mute: '38;5;137',
    dim: '38;5;94',
    track: '38;5;58',
    glow: '38;5;229',
    border: '38;5;136',
    canvas: 16,
    margin: 233,
    card: 232,
    halo: 233,
    shadow: 16,
    bg: [16, 233, 234],
    bgStyle: 'flat',
    fill: '━',
    empty: '─',
    frame: ['┌', '┐', '└', '┘', '─', '│'],
    whispers: {
      focus: { running: 'Beam steady — one line at a time.', paused: 'Beam parked.', idle: 'Warm up the tube. Set an intent.' },
      shortbreak: { running: 'Persistence fading. Let it.', paused: '—', idle: 'Short refresh.' },
      longbreak: { running: 'Tube cooling. Step away.', paused: '—', idle: 'Long cool-down.' },
    },
  },
  ice: {
    label: 'Ice',
    mark: '❄',
    tagline: 'cold glass lcd',
    accent: '38;5;123',
    ok: '38;5;87',
    warn: '38;5;153',
    text: '38;5;195',
    soft: '38;5;110',
    mute: '38;5;67',
    dim: '38;5;24',
    track: '38;5;24',
    glow: '38;5;159',
    border: '38;5;38',
    canvas: 16,
    margin: 17,
    card: 234,
    halo: 17,
    shadow: 16,
    bg: [16, 17, 234],
    bgStyle: 'mist',
    fill: '▰',
    empty: '▱',
    frame: ['╭', '╮', '╰', '╯', '─', '│'],
    whispers: {
      focus: { running: 'Cold air, clear mind.', paused: 'Frozen mid-frame.', idle: 'Carve the intent first.' },
      shortbreak: { running: 'Let the glass defog.', paused: '—', idle: 'Short thaw.' },
      longbreak: { running: 'Full whiteout. Walk away.', paused: '—', idle: 'Long thaw.' },
    },
  },
  receipt: {
    label: 'Receipt',
    mark: '§',
    tagline: 'thermal paper stub',
    accent: '38;5;160',
    ok: '38;5;28',
    warn: '38;5;130',
    text: '38;5;235',
    soft: '38;5;240',
    mute: '38;5;245',
    dim: '38;5;249',
    track: '38;5;252',
    glow: '38;5;196',
    border: '38;5;244',
    canvas: 233,
    margin: 236,
    card: 255,
    halo: 250,
    shadow: 232,
    bg: [233, 236, 255],
    bgStyle: 'paper',
    fill: '█',
    empty: '░',
    frame: ['╭', '╮', '╰', '╯', '┄', '┆'],
    whispers: {
      focus: { running: 'ITEM 001 · ONE FOCUSED BLOCK', paused: 'TRANSACTION HELD', idle: 'INSERT INTENT TO BEGIN' },
      shortbreak: { running: 'CHANGE DUE: 5 MIN', paused: 'TRANSACTION HELD', idle: 'BREAK VOUCHER READY' },
      longbreak: { running: 'REFUND: 15 MIN TO YOU', paused: 'TRANSACTION HELD', idle: 'LONG BREAK VOUCHER' },
    },
  },
};

const TUI_THEME_IDS = Object.keys(TUI_THEMES);

/** Layout only — pair with any color scheme (`T` layout · `C` colors). */
const TUI_TEMPLATES = [
  {
    id: 'studio',
    label: 'Studio',
    caption: 'centered card · block clock & task',
    layout: 'studio',
    width: 0.6,
    chrome: 'full',
    align: 'center',
  },
  {
    id: 'billboard',
    label: 'Billboard',
    caption: 'wide hero timer · minimal chrome',
    layout: 'billboard',
    width: 0.72,
    chrome: 'minimal',
    align: 'center',
  },
  {
    id: 'ticket',
    label: 'Ticket',
    caption: 'narrow receipt · dotted dividers',
    layout: 'ticket',
    width: 0.46,
    chrome: 'flat',
    align: 'left',
  },
  {
    id: 'dashboard',
    label: 'Dashboard',
    caption: 'stats banner · clock beside bar',
    layout: 'dashboard',
    width: 0.66,
    chrome: 'full',
    align: 'center',
  },
  {
    id: 'phosphor',
    label: 'Phosphor',
    caption: 'crt brackets · flat canvas',
    layout: 'phosphor',
    width: 0.64,
    chrome: 'none',
    align: 'center',
  },
  {
    id: 'orbit',
    label: 'Orbit',
    caption: 'dial dots above the clock',
    layout: 'orbit',
    width: 0.62,
    chrome: 'full',
    align: 'center',
  },
  {
    id: 'radar',
    label: 'Radar',
    caption: 'sweep scope · split pane',
    layout: 'radar',
    width: 0.7,
    chrome: 'full',
    align: 'left',
  },
  {
    id: 'marquee',
    label: 'Marquee',
    caption: 'chasing lights · tonight only',
    layout: 'marquee',
    width: 0.66,
    chrome: 'minimal',
    align: 'center',
  },
  {
    id: 'zen',
    label: 'Zen',
    caption: 'raked sand · stepping stones',
    layout: 'zen',
    width: 0.6,
    chrome: 'none',
    align: 'center',
  },
  {
    id: 'flapboard',
    label: 'Split-flap',
    caption: 'departure board · hinged digits',
    layout: 'flapboard',
    width: 0.62,
    chrome: 'flat',
    align: 'left',
  },
  {
    id: 'sheet',
    label: 'Sheet',
    caption: 'grid timer · sheet & session box',
    layout: 'sheet',
    width: 0.68,
    chrome: 'flat',
    align: 'left',
  },
  {
    id: 'lcd',
    label: 'LCD',
    caption: 'segment display · focus panel',
    layout: 'lcd',
    width: 0.48,
    chrome: 'none',
    align: 'center',
  },
  {
    id: 'watch',
    label: 'Watch',
    caption: 'analog face · hud dial',
    layout: 'watch',
    width: 0.5,
    chrome: 'full',
    align: 'center',
  },
];

const TUI_TEMPLATE_IDS = TUI_TEMPLATES.map((t) => t.id);
const TUI_TEMPLATE_BY_ID = Object.fromEntries(TUI_TEMPLATES.map((t) => [t.id, t]));

function resolveTemplateId(prefs = {}) {
  if (prefs.template && TUI_TEMPLATE_BY_ID[prefs.template]) return prefs.template;
  return 'studio';
}

function resolveThemeId(prefs = {}) {
  if (prefs.theme && TUI_THEMES[prefs.theme]) return prefs.theme;
  return 'ember';
}

function tuiTemplate(templateId = 'studio') {
  return TUI_TEMPLATE_BY_ID[templateId] || TUI_TEMPLATE_BY_ID.studio;
}

function loadTuiPrefs() {
  const envTemplate = process.env.POMO_TUI_TEMPLATE;
  const envTheme = process.env.POMO_TUI_THEME;
  if (envTemplate && TUI_TEMPLATE_BY_ID[envTemplate] && envTheme && TUI_THEMES[envTheme]) {
    return { template: envTemplate, theme: envTheme };
  }
  if (envTemplate && TUI_TEMPLATE_BY_ID[envTemplate]) {
    return { template: envTemplate, theme: resolveThemeId({}) };
  }
  if (envTheme && TUI_THEMES[envTheme]) {
    return { template: 'studio', theme: envTheme };
  }
  if (!existsSync(TUI_PREFS_FILE)) return { template: 'studio', theme: 'ember' };
  try {
    const data = JSON.parse(readFileSync(TUI_PREFS_FILE, 'utf8'));
    return { template: resolveTemplateId(data), theme: resolveThemeId(data) };
  } catch {
    return { template: 'studio', theme: 'ember' };
  }
}

function saveTuiPrefs(prefs) {
  try {
    mkdirSync(dirname(TUI_PREFS_FILE), { recursive: true });
    writeFileSync(TUI_PREFS_FILE, `${JSON.stringify(prefs, null, 2)}\n`, 'utf8');
  } catch {
    /* best effort */
  }
}

function tryReadState() {
  if (!existsSync(STATE_FILE)) return null;
  try {
    return JSON.parse(readFileSync(STATE_FILE, 'utf8'));
  } catch {
    return null;
  }
}

function formatClock(seconds) {
  const safe = Math.max(0, Number(seconds) || 0);
  const m = Math.floor(safe / 60);
  const s = safe % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function extrapolateState(s, elapsedMs) {
  if (!s || s.phase !== 'running' || elapsedMs <= 0) return s;
  const total = Number(s.totalSeconds) || 0;
  const remaining = Math.max(0, (Number(s.remainingSeconds) || 0) - elapsedMs / 1000);
  const wholeRemaining = Math.ceil(remaining);
  if (wholeRemaining === s.remainingSeconds && elapsedMs < 1000) {
    return {
      ...s,
      progress: total > 0 ? (total - remaining) / total : s.progress,
    };
  }
  return {
    ...s,
    remainingSeconds: wholeRemaining,
    clock: formatClock(wholeRemaining),
    progress: total > 0 ? (total - remaining) / total : s.progress,
  };
}

function termSize() {
  const envCols = Number(process.env.POMO_SCREENSHOT_COLS);
  const envRows = Number(process.env.POMO_SCREENSHOT_ROWS);
  if (Number.isFinite(envCols) && envCols > 0 && Number.isFinite(envRows) && envRows > 0) {
    return { cols: Math.floor(envCols), rows: Math.floor(envRows) };
  }
  return {
    cols: Math.max(40, process.stdout.columns || 80),
    rows: Math.max(16, process.stdout.rows || 24),
  };
}

let screenshotRender = false;

function ansi256ToRgb(code) {
  const n = Number(code);
  if (!Number.isFinite(n)) return [200, 200, 200];
  if (n < 16) {
    const base = [
      [0, 0, 0], [128, 0, 0], [0, 128, 0], [128, 128, 0],
      [0, 0, 128], [128, 0, 128], [0, 128, 128], [192, 192, 192],
      [128, 128, 128], [255, 0, 0], [0, 255, 0], [255, 255, 0],
      [0, 0, 255], [255, 0, 255], [0, 255, 255], [255, 255, 255],
    ];
    return base[n] || [200, 200, 200];
  }
  if (n < 232) {
    const idx = n - 16;
    const r = Math.floor(idx / 36);
    const g = Math.floor((idx % 36) / 6);
    const b = idx % 6;
    return [r * 51, g * 51, b * 51];
  }
  const gray = (n - 232) * 10 + 8;
  return [gray, gray, gray];
}

function screenshotPalette(themeId = 'ember') {
  const theme = TUI_THEMES[themeId] || TUI_THEMES.ember;
  const role = (code) => ansi256ToRgb(code);
  return {
    text: role(theme.text),
    soft: role(theme.soft ?? theme.mute),
    accent: role(theme.accent),
    ok: role(theme.ok),
    warn: role(theme.warn),
    mute: role(theme.mute),
    dim: role(theme.dim ?? theme.mute),
    track: role(theme.track ?? theme.dim ?? theme.mute),
    glow: role(theme.glow),
    border: role(theme.border ?? theme.mute),
    key: role(theme.key ?? theme.mute),
    canvas: role(theme.canvas ?? theme.bg[0]),
    margin: role(theme.margin ?? theme.bg[1] ?? theme.bg[0]),
    card: role(theme.card ?? theme.bg[2] ?? theme.bg[0]),
    halo: role(theme.halo ?? theme.margin ?? theme.bg[1] ?? theme.bg[0]),
    shadow: role(theme.shadow ?? theme.canvas ?? theme.bg[0]),
    label: theme.label,
    mark: theme.mark,
    frame: theme.frame,
  };
}

function parseAnsiCells(text, defaultFg, defaultBg) {
  const cells = [];
  let fg = defaultFg;
  let bg = defaultBg;
  let bold = false;
  const src = String(text ?? '');
  for (let i = 0; i < src.length; i++) {
    if (src[i] === '\x1b' && src[i + 1] === '[') {
      let j = i + 2;
      const parts = [];
      while (j < src.length && src[j] !== 'm') {
        let k = j;
        while (k < src.length && src[k] !== ';' && src[k] !== 'm') k++;
        parts.push(src.slice(j, k));
        j = src[k] === ';' ? k + 1 : k;
      }
      if (src[j] === 'm') {
        for (const part of parts) {
          if (part === '0' || part === '') {
            fg = defaultFg;
            bg = defaultBg;
            bold = false;
          } else if (part === '1') bold = true;
          else if (part === '22') bold = false;
          else if (part.startsWith('38;5;')) fg = ansi256ToRgb(part.slice(5));
          else if (part.startsWith('48;5;')) bg = ansi256ToRgb(part.slice(5));
          else if (/^\d+$/.test(part)) fg = ansi256ToRgb(part);
        }
        i = j;
        continue;
      }
    }
    const ch = src[i];
    if (ch === '\n' || ch === '\r') continue;
    const ink = bold ? fg.map((v) => Math.min(255, v + 28)) : fg;
    cells.push({ ch, fg: ink, bg: [...bg] });
  }
  return cells;
}

function makeScreenshotGrid(cols, rows, bg, fg) {
  const grid = [];
  for (let y = 0; y < rows; y++) {
    const row = [];
    for (let x = 0; x < cols; x++) row.push({ ch: ' ', fg: [...fg], bg: [...bg] });
    grid.push(row);
  }
  return grid;
}

function blitAnsiLine(grid, x, y, text, defaultFg, defaultBg) {
  if (y < 0 || y >= grid.length) return;
  const cells = parseAnsiCells(text, defaultFg, defaultBg);
  for (let i = 0; i < cells.length; i++) {
    const col = x + i;
    if (col < 0 || col >= grid[0].length) break;
    grid[y][col] = cells[i];
  }
}

function fillScreenshotRect(grid, x, y, w, h, bg) {
  for (let row = y; row < y + h; row++) {
    if (row < 0 || row >= grid.length) continue;
    for (let col = x; col < x + w; col++) {
      if (col < 0 || col >= grid[0].length) continue;
      grid[row][col] = { ch: ' ', fg: [...bg], bg: [...bg] };
    }
  }
}

function composeScreenshotGrid(cardLines, templateId, themeId, cols, rows, celebrate, tick, hint = null) {
  const template = tuiTemplate(templateId);
  const pal = screenshotPalette(themeId);
  const grid = makeScreenshotGrid(cols, rows, pal.canvas, pal.text);
  const lineWidth = Math.max(1, ...cardLines.map(visibleLen));
  const startRow = Math.max(2, Math.floor((rows - cardLines.length) / 2));
  const startCol = Math.max(1, Math.floor((cols - lineWidth) / 2));
  const haloPad = 1;
  const haloRow0 = Math.max(1, startRow - haloPad);
  const haloRow1 = Math.min(rows, startRow + cardLines.length - 1 + haloPad);
  const haloCol0 = Math.max(1, startCol - haloPad);
  const haloWidth = Math.min(cols - haloCol0 + 1, lineWidth + haloPad * 2);
  const chrome = template.chrome ?? 'full';

  if (chrome === 'full' || chrome === 'minimal') {
    if (chrome === 'full') {
      const shadowCol = Math.min(cols, haloCol0 + 1);
      const shadowWidth = Math.min(cols - shadowCol + 1, haloWidth);
      fillScreenshotRect(grid, shadowCol - 1, haloRow0, shadowWidth, haloRow1 - haloRow0 + 2, pal.shadow);
    }
    const haloBg = celebrate && tick % 6 < 2 ? pal.glow : pal.halo;
    fillScreenshotRect(grid, haloCol0 - 1, haloRow0 - 1, haloWidth, haloRow1 - haloRow0 + 2, haloBg);
  }

  for (let i = 0; i < cardLines.length; i++) {
    blitAnsiLine(grid, startCol - 1, startRow - 1 + i, cardLines[i], pal.text, pal.card);
  }

  const footerText = hint || 'space · a · i · T template · t theme · n · h HUD · 4 · ? · q';
  const shown = truncate(footerText, Math.max(1, cols - 2));
  const pad = Math.max(0, Math.floor((cols - shown.length) / 2));
  blitAnsiLine(grid, 0, rows - 1, `${' '.repeat(pad)}${shown}`, pal.key, pal.canvas);

  return { width: cols, height: rows, rows: grid };
}

function screenshotState(s) {
  if (!s) return null;
  const total = Number(s.totalSeconds) || 25 * 60;
  const remaining = s.phase === 'running'
    ? Number(s.remainingSeconds) || total
    : total;
  return {
    ...s,
    phase: s.phase === 'running' ? 'running' : 'idle',
    sessionType: s.sessionType || 'focus',
    remainingSeconds: remaining,
    clock: formatClock(remaining),
    progress: s.phase === 'running' ? (Number(s.progress) || 0) : 0,
    intent: s.intent || 'WIN',
  };
}

function renderScreenshotSpec(s, templateId, themeId, cols, rows) {
  const prev = screenshotRender;
  screenshotRender = true;
  try {
    const width = cardWidth(cols, tuiTemplate(templateId));
    const card = buildCardLines(s, null, templateId, themeId, width, false, 0);
    return composeScreenshotGrid(card, templateId, themeId, cols, rows, false, 0);
  } finally {
    screenshotRender = prev;
  }
}

function writeScreenshot(args) {
  const templateId = takeFlag(args, 'template') || 'studio';
  const themeId = takeFlag(args, 'theme') || 'ember';
  const out = takeFlag(args, 'out');
  const cols = Number(takeFlag(args, 'cols') || 100);
  const rows = Number(takeFlag(args, 'rows') || 40);
  const jsonOnly = hasFlag(args, '--json');
  if (!TUI_TEMPLATE_BY_ID[templateId]) die(`unknown template: ${templateId}`);
  if (!TUI_THEMES[themeId]) die(`unknown theme: ${themeId}`);
  if (!jsonOnly && !out) die('usage: pomo screenshot --out <file.png> [--template id] [--theme id] [--cols n] [--rows n]');
  process.env.POMO_SCREENSHOT_COLS = String(cols);
  process.env.POMO_SCREENSHOT_ROWS = String(rows);
  const raw = tryReadState();
  const spec = renderScreenshotSpec(screenshotState(raw), templateId, themeId, cols, rows);
  if (jsonOnly) {
    console.log(JSON.stringify(spec));
    return;
  }
  const tmp = join(tmpdir(), `pomo-shot-${Date.now()}.json`);
  writeFileSync(tmp, JSON.stringify(spec));
  const scriptsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'scripts');
  const bin = join(scriptsDir, 'render-ansi-png-bin');
  const script = join(scriptsDir, 'render-ansi-png.swift');
  if (!existsSync(bin) && !existsSync(script)) die(`missing renderer: ${script}`);
  try {
    if (existsSync(bin)) execFileSync(bin, [tmp, out], { stdio: 'inherit' });
    else execFileSync('swiftc', ['-O', '-o', bin, script], { stdio: 'inherit' });
    if (existsSync(bin)) execFileSync(bin, [tmp, out], { stdio: 'inherit' });
    else execFileSync('swift', [script, tmp, out], { stdio: 'inherit' });
  } finally {
    try { rmSync(tmp); } catch { /* ignore */ }
  }
  console.log(out);
}

const CELEBRATE_MS = 900;

function tuiTick() {
  return Math.floor(Date.now() / 140);
}

function stateFingerprint(s, edit = null, templateId = 'studio', themeId = 'ember', layout = null, celebrating = false) {
  if (!s) return 'missing';
  const { cols, rows } = layout || termSize();
  const pulse = celebrating ? tuiTick() : 0;
  return [
    s.phase,
    s.remainingSeconds,
    s.sessionType,
    s.intent,
    s.audioPlaying,
    s.audioURL,
    s.hudVisible,
    s.watchface,
    s.completedFocusCount,
    s.focusToday,
    pulse,
    templateId,
    themeId,
    cols,
    rows,
    edit?.intentMode ? 1 : 0,
    edit?.intentDraft ?? '',
    edit?.overlay ?? '',
  ].join('|');
}

function celebrateSnapshot(s) {
  if (!s) return null;
  return {
    phase: s.phase,
    remainingSeconds: s.remainingSeconds,
    sessionType: s.sessionType,
    completedFocusCount: s.completedFocusCount,
    totalSeconds: s.totalSeconds,
  };
}

function detectCelebrate(prev, next) {
  if (!next) return false;
  if (prev && prev.phase !== 'running' && next.phase === 'running') return true;
  if (prev && prev.completedFocusCount !== next.completedFocusCount) return true;
  if (prev?.sessionType !== next.sessionType) return true;
  if (next.phase === 'running' && prev) {
    const prevMin = Math.floor(prev.remainingSeconds / 60);
    const nextMin = Math.floor(next.remainingSeconds / 60);
    if (prevMin !== nextMin && next.remainingSeconds % 60 === 0) return true;
    if (prev.totalSeconds > 0 && next.totalSeconds > 0) {
      const prevPct = Math.floor((1 - prev.remainingSeconds / prev.totalSeconds) * 100);
      const nextPct = Math.floor((1 - next.remainingSeconds / next.totalSeconds) * 100);
      for (const mark of [25, 50, 75]) {
        if (prevPct < mark && nextPct >= mark) return true;
      }
    }
  }
  return false;
}

function tuiPalette(themeId = 'ember') {
  const theme = TUI_THEMES[themeId] || TUI_THEMES.ember;
  const on = screenshotRender || (process.stdout.isTTY && !process.env.NO_COLOR);
  if (!on) {
    return {
      r: '',
      t: '',
      b: '',
      d: '',
      hi: '',
      text: '',
      soft: '',
      accent: '',
      ok: '',
      warn: '',
      mute: '',
      dim: '',
      track: '',
      glow: '',
      border: '',
      key: '',
      bg: () => '',
      fill256: () => '',
      canvas: () => '',
      margin: () => '',
      wash: () => '',
      card: () => '',
      halo: () => '',
      shadow: () => '',
      fill: theme.fill,
      empty: theme.empty,
      label: theme.label,
      mark: theme.mark,
      tagline: theme.tagline,
      frame: theme.frame,
    };
  }
  const esc = (code) => `\x1b[${code}m`;
  const bg = (shade) => esc(`38;5;${theme.bg[shade] ?? theme.bg[0]}`);
  const fill256 = (shade) => esc(`48;5;${shade}`);
  const canvas = () => fill256(theme.canvas ?? theme.bg[0]);
  const margin = () => fill256(theme.margin ?? theme.bg[1] ?? theme.bg[0]);
  const wash = () => fill256(theme.bg[1] ?? theme.margin ?? theme.bg[0]);
  const card = () => fill256(theme.card ?? theme.bg[2] ?? theme.bg[0]);
  const halo = () => fill256(theme.halo ?? theme.margin ?? theme.bg[1] ?? theme.bg[0]);
  const shadow = () => fill256(theme.shadow ?? theme.canvas ?? theme.bg[0]);
  return {
    r: '\x1b[0m',
    t: '\x1b[22;39m',
    b: '\x1b[1m',
    d: '\x1b[2m',
    hi: esc(theme.text ?? '97'),
    text: esc(theme.text ?? '97'),
    soft: esc(theme.soft ?? theme.mute),
    accent: esc(theme.accent),
    ok: esc(theme.ok),
    warn: esc(theme.warn),
    mute: esc(theme.mute),
    dim: esc(theme.dim ?? theme.mute),
    track: esc(theme.track ?? theme.dim ?? theme.mute),
    glow: esc(theme.glow),
    border: esc(theme.border ?? theme.mute),
    key: esc(theme.key ?? theme.mute),
    bg,
    fill256,
    canvas,
    margin,
    wash,
    card,
    halo,
    shadow,
    fill: theme.fill,
    empty: theme.empty,
    label: theme.label,
    mark: theme.mark,
    tagline: theme.tagline,
    frame: theme.frame,
  };
}

function visibleLen(text) {
  return String(text).replace(/\x1b\[[0-9;]*m/g, '').length;
}

function padLine(text, width) {
  const pad = Math.max(0, width - visibleLen(text));
  return `${text}${' '.repeat(pad)}`;
}

function cursorAt(row, col) {
  return `\x1b[${row};${col}H`;
}

function cardWidth(cols, template = tuiTemplate()) {
  const fit = Math.max(32, cols - 4);
  const ratio = template.width ?? 0.6;
  const preferred = Math.max(34, Math.min(72, Math.floor(cols * ratio)));
  return Math.min(preferred, fit);
}

function frameInk(c, celebrate, tick) {
  if (celebrate && tick % 6 < 2) return c.glow;
  return c.border;
}

function frameRule(width, frame, c, celebrate = false, tick = 0) {
  const ink = frameInk(c, celebrate, tick);
  return `${ink}${frame[0]}${frame[4].repeat(width)}${frame[1]}${c.t}`;
}

function frameFoot(width, frame, c, celebrate = false, tick = 0) {
  const ink = frameInk(c, celebrate, tick);
  return `${ink}${frame[2]}${frame[4].repeat(width)}${frame[3]}${c.t}`;
}

function boxRow(text, width, frame, c, celebrate = false, tick = 0) {
  const ink = frameInk(c, celebrate, tick);
  return `${ink}${frame[5]}${c.t} ${padLine(text, width - 2)} ${ink}${frame[5]}${c.t}`;
}

function centerRow(text, width) {
  const pad = Math.max(0, Math.floor((width - visibleLen(text)) / 2));
  return `${' '.repeat(pad)}${text}`;
}

function splitRow(left, right, width, gap = '  ') {
  const rightLen = visibleLen(right);
  const gapLen = visibleLen(gap);
  if (visibleLen(left) + gapLen + rightLen > width) return padLine(left, width);
  return `${padLine(left, width - rightLen - gapLen)}${gap}${right}`;
}

function sessionLabel(type) {
  switch ((type || '').toLowerCase()) {
    case 'focus':
      return 'Focus';
    case 'shortbreak':
      return 'Short break';
    case 'longbreak':
      return 'Long break';
    default:
      return type || '—';
  }
}

function titleCase(value) {
  const text = String(value || '');
  if (!text) return '—';
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function phaseTone(phase, c) {
  switch (phase) {
    case 'running':
      return `${c.ok}●${c.t}`;
    case 'paused':
      return `${c.warn}❚❚${c.t}`;
    default:
      return `${c.mute}○${c.t}`;
  }
}

function sessionKind(type) {
  const t = (type || '').toLowerCase();
  if (t === 'shortbreak') return 'shortbreak';
  if (t === 'longbreak') return 'longbreak';
  return 'focus';
}

function tuiWhisper(s, themeId) {
  const theme = TUI_THEMES[themeId] || TUI_THEMES.ember;
  const kind = sessionKind(s.sessionType);
  const phase = s.phase || 'idle';
  return theme.whispers?.[kind]?.[phase] || theme.tagline;
}

function progressBar(progress, c, width, celebrate, tick) {
  const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
  const filled = Math.round(clamped * width);
  const head = filled > 0 && filled < width ? 1 : 0;
  const body = Math.max(0, filled - head);
  const headColor = celebrate && tick % 6 < 2 ? c.glow : c.accent;
  const headCh = head ? `${headColor}${c.b}${c.fill}${c.t}` : '';
  const empty = width - filled;
  const track = empty > 0 ? `${c.track}${c.empty.repeat(empty)}${c.t}` : '';
  return `${c.accent}${c.fill.repeat(body)}${headCh}${track}`;
}

function cycleDots(completed, slots = 4) {
  const done = Number(completed) || 0;
  const pos = done % slots;
  return Array.from({ length: slots }, (_, i) => (i < pos ? '●' : '○')).join(' ');
}

function audioMeter(playing, celebrate, tick) {
  if (!playing) return '';
  if (!celebrate) return '▶';
  const bars = '▁▂▃▄▅▆▇';
  return Array.from({ length: 5 }, (_, i) => bars[(tick + i * 2) % bars.length]).join('');
}

function audioLine(s, celebrate, tick) {
  if (!s.audioURL) return '—';
  const fav = (s.favorites || []).find((f) => f.url === s.audioURL);
  const label = fav ? fav.title : s.audioURL;
  const meter = audioMeter(s.audioPlaying, celebrate, tick);
  const prefix = meter ? `${meter} ` : (s.audioPlaying ? '▶ ' : '⏸ ');
  return `${prefix}${label}`;
}

function truncate(text, max) {
  const value = String(text || '');
  if (max <= 0) return '';
  if (max === 1 && value.length > 1) return '…';
  if (value.length <= max) return value;
  return `${value.slice(0, max - 1)}…`;
}

function fieldRow(label, value, c, width, frame, valueWidth, celebrate, tick) {
  const text = `${c.mute}${label.padEnd(7)}${c.t} ${c.text}${truncate(value, valueWidth)}${c.t}`;
  return boxRow(text, width, frame, c, celebrate, tick);
}

function formatClockDisplay(clock, wide) {
  if (!wide) return clock;
  return clock.replace(':', ' : ');
}

const ASCII_BIG = {
  '0': ['███  ', '█ █  ', '█ █  ', '█ █  ', '███  '],
  '1': [' █   ', '██   ', ' █   ', ' █   ', '███  '],
  '2': ['███  ', '  █  ', '███  ', '█    ', '███  '],
  '3': ['███  ', '  █  ', '███  ', '  █  ', '███  '],
  '4': ['█ █  ', '█ █  ', '███  ', '  █  ', '  █  '],
  '5': ['███  ', '█    ', '███  ', '  █  ', '███  '],
  '6': ['███  ', '█    ', '███  ', '█ █  ', '███  '],
  '7': ['███  ', '  █  ', '  █  ', ' █   ', ' █   '],
  '8': ['███  ', '█ █  ', '███  ', '█ █  ', '███  '],
  '9': ['███  ', '█ █  ', '███  ', '  █  ', '███  '],
  ':': ['     ', '  █  ', '     ', '  █  ', '     '],
  '-': ['     ', '███  ', '     ', '     ', '     '],
  ' ': ['     ', '     ', '     ', '     ', '     '],
};

/** Seven-segment lcd glyphs — pairs with amber/retro themes. */
const ASCII_SEGMENT = {
  '0': [' ╔══╗ ', ' ║  ║ ', ' ║  ║ ', ' ║  ║ ', ' ╚══╝ '],
  '1': ['   ╔╗ ', '  ╔╝ ', '   ║ ', '   ║ ', '  ╚╝ '],
  '2': [' ╔══╗ ', '    ║ ', ' ╔══╝ ', ' ║    ', ' ╚══╝ '],
  '3': [' ╔══╗ ', '    ║ ', '  ══╗ ', '    ║ ', ' ╚══╝ '],
  '4': [' ║  ║ ', ' ║  ║ ', ' ╚══╬ ', '    ║ ', '    ║ '],
  '5': [' ╔══╗ ', ' ║    ', ' ╚══╗ ', '    ║ ', ' ╚══╝ '],
  '6': [' ╔══╗ ', ' ║    ', ' ╠══╗ ', ' ║  ║ ', ' ╚══╝ '],
  '7': [' ╔══╗ ', '    ║ ', '   ║  ', '  ║   ', '  ║   '],
  '8': [' ╔══╗ ', ' ║  ║ ', ' ╠══╣ ', ' ║  ║ ', ' ╚══╝ '],
  '9': [' ╔══╗ ', ' ║  ║ ', ' ╚══╣ ', '    ║ ', ' ╚══╝ '],
  ':': ['      ', '  ■   ', '      ', '  ■   ', '      '],
  '-': ['      ', ' ═══  ', '      ', '      ', '      '],
  ' ': ['      ', '      ', '      ', '      ', '      '],
};

const ASCII_SMALL = {
  ' ': ['    ', '    ', '    '],
  '0': ['███ ', '█ █ ', '███ '],
  '1': [' █  ', '██  ', ' █  '],
  '2': ['███ ', '  █ ', '███ '],
  '3': ['███ ', ' ██ ', '███ '],
  '4': ['█ █ ', '███ ', '  █ '],
  '5': ['███ ', '██  ', '███ '],
  '6': ['███ ', '██  ', '███ '],
  '7': ['███ ', '  █ ', '  █ '],
  '8': ['███ ', '███ ', '███ '],
  '9': ['███ ', '███ ', '  █ '],
  A: ['███ ', '█ █ ', '███ '],
  B: ['██╗ ', '███ ', '███ '],
  C: ['███ ', '█   ', '███ '],
  D: ['██╗ ', '█ █ ', '███ '],
  E: ['███ ', '██  ', '███ '],
  F: ['███ ', '██  ', '█   '],
  G: ['███ ', '█ █ ', '███ '],
  H: ['█ █ ', '███ ', '█ █ '],
  I: ['███ ', ' █  ', '███ '],
  J: ['  █ ', '  █ ', '███ '],
  K: ['█ █ ', '██  ', '█ █ '],
  L: ['█   ', '█   ', '███ '],
  M: ['█ █ ', '███ ', '█ █ '],
  N: ['███ ', '█ █ ', '█ █ '],
  O: ['███ ', '█ █ ', '███ '],
  P: ['███ ', '███ ', '█   '],
  Q: ['███ ', '█ █ ', '█ █ '],
  R: ['███ ', '██  ', '█ █ '],
  S: ['███ ', ' █  ', '███ '],
  T: ['███ ', ' █  ', ' █  '],
  U: ['█ █ ', '█ █ ', '███ '],
  V: ['█ █ ', '█ █ ', ' █  '],
  W: ['█ █ ', '███ ', '███ '],
  X: ['█ █ ', ' █  ', '█ █ '],
  Y: ['█ █ ', ' █  ', ' █  '],
  Z: ['███ ', ' █  ', '███ '],
  '-': ['    ', '███ ', '    '],
  '.': ['    ', '    ', ' █  '],
  "'": [' █  ', ' █  ', '    '],
  '▌': [' █  ', ' █  ', ' █  '],
};

function asciiGlyph(ch, glyphs) {
  const key = ch === ch.toLowerCase() && ch >= 'a' && ch <= 'z'
    ? ch.toUpperCase()
    : ch;
  return glyphs[key] || glyphs[ch] || glyphs[' '] || glyphs.A;
}

function renderAsciiString(text, glyphs, gap = 1) {
  const chars = [...String(text || '')];
  const sample = glyphs['0'] || glyphs.A || glyphs[' '];
  const height = sample.length;
  const rows = Array.from({ length: height }, () => '');
  chars.forEach((ch, i) => {
    const g = asciiGlyph(ch, glyphs);
    const w = g[0].length;
    if (i > 0) {
      for (let r = 0; r < height; r++) rows[r] += ' '.repeat(gap);
    }
    for (let r = 0; r < height; r++) rows[r] += g[r] ?? ' '.repeat(w);
  });
  const trimmedRows = rows.map((row) => row.trimEnd());
  const visualWidth = Math.max(0, ...trimmedRows.map((row) => row.length));
  return {
    rows: trimmedRows.map((row) => row.padEnd(visualWidth)),
    width: visualWidth,
    height,
  };
}

function colorAsciiRows(rows, ink, c) {
  return rows.map((row) => `${ink}${row}${c.t}`);
}

function asciiClockRows(clock, inner, c) {
  const text = String(clock || '--:--').replace(/\s/g, '');
  const rendered = renderAsciiString(text, ASCII_BIG, 1);
  if (rendered.width > inner) {
    return {
      rows: [`${c.accent}${c.b}${formatClockDisplay(clock, false)}${c.t}`],
      height: 1,
      fallback: true,
    };
  }
  return {
    rows: colorAsciiRows(rendered.rows, `${c.accent}${c.b}`, c),
    height: rendered.height,
    fallback: false,
  };
}

function wrapAsciiSmall(text, inner) {
  const words = String(text || '').trim().split(/\s+/).filter(Boolean);
  if (!words.length) return [];
  const lines = [];
  let current = '';
  for (const word of words) {
    const next = current ? `${current} ${word}` : word;
    if (renderAsciiString(next, ASCII_SMALL, 1).width > inner && current) {
      lines.push(current);
      current = word;
    } else {
      current = next;
    }
  }
  if (current) lines.push(current);
  return lines.slice(0, 2);
}

function asciiIntentBlocks(text, inner, c, accent = false) {
  const lines = wrapAsciiSmall(text, inner);
  if (!lines.length) return { blocks: [], height: 0 };
  const ink = accent ? `${c.accent}${c.b}` : `${c.dim}`;
  const blocks = lines.map((line) => ({
    rows: colorAsciiRows(renderAsciiString(line, ASCII_SMALL, 1).rows, ink, c),
    height: 3,
  }));
  return { blocks, height: blocks.length * 3 };
}

function backgroundRow(cols, c) {
  return `${c.canvas()}${' '.repeat(cols)}${c.r}\x1b[K`;
}

function statRow(label, value, c, inner) {
  const val = truncate(String(value ?? '—'), Math.max(8, inner - label.length - 3));
  return `${c.mute}${label}${c.t} ${c.text}${val}${c.t}`;
}

function alignRow(text, inner, align = 'center') {
  if (align === 'left') return padLine(text, inner);
  return centerRow(text, inner);
}

function dividerRow(width, frame, c, celebrate, tick, ch = '─') {
  const inner = width - 2;
  return boxRow(`${c.dim}${ch.repeat(Math.max(4, inner))}${c.t}`, width, frame, c, celebrate, tick);
}

function spacerRow(width, frame, c, celebrate, tick) {
  return boxRow('', width, frame, c, celebrate, tick);
}

function progressLabel(pct) {
  return `${String(pct).padStart(2, ' ')}%`;
}

function progressRow(progress, pct, c, inner, align = 'center', celebrate = false, tick = 0) {
  const label = progressLabel(pct);
  const gap = '  ';
  const barWidth = Math.max(4, inner - visibleLen(gap) - visibleLen(label));
  const bar = progressBar(progress, c, barWidth, celebrate, tick);
  const text = `${bar}${gap}${c.soft}${label}${c.t}`;
  return alignRow(text, inner, align);
}

function clockProgressRow(clock, progress, pct, c, inner, celebrate, tick) {
  const clockText = `${c.accent}${c.b}${clock}${c.t}`;
  const label = progressLabel(pct);
  const gap = '  ';
  const labelGap = ' ';
  const barWidth = Math.max(
    4,
    inner - visibleLen(clock) - visibleLen(gap) - visibleLen(labelGap) - visibleLen(label),
  );
  const bar = progressBar(progress, c, barWidth, celebrate, tick);
  return padLine(`${clockText}${gap}${bar}${labelGap}${c.soft}${label}${c.t}`, inner);
}

function promptBody(text) {
  return String(text || '').replace(/^>\s*/, '');
}

function cardContext(s, edit, template, themeId, width, celebrate, tick) {
  const c = tuiPalette(themeId);
  const frame = c.frame;
  const inner = width - 2;
  const valueWidth = Math.max(12, inner - 10);
  const progress = Number(s.progress) || 0;
  const pct = Math.round(Math.max(0, Math.min(1, progress)) * 100);
  const session = sessionLabel(s.sessionType);
  const phase = s.phase || 'idle';
  const bar = progressBar(progress, c, inner, celebrate, tick);
  const editingIntent = edit?.intentMode === true;
  const whisper = tuiWhisper(s, themeId);
  const roundNum = ((Number(s.completedFocusCount) || 0) % 4) + 1;
  const cycle = `${c.dim}${cycleDots(s.completedFocusCount)}${c.t}`;
  const audio = truncate(audioLine(s, celebrate, tick), valueWidth);
  const clock = s.clock || '--:--';
  const clockBlock = asciiClockRows(clock, inner, c);
  const intentText = editingIntent
    ? `${edit.intentDraft}▌`
    : s.intent || 'PRESS I';
  const intentAscii = asciiIntentBlocks(intentText, inner, c, editingIntent || Boolean(s.intent));
  const plainIntent = editingIntent
    ? truncate(`${edit.intentDraft}▌`, inner)
    : s.intent
      ? `“${truncate(s.intent, inner - 2)}”`
      : 'press i to name this stretch';
  return {
    c,
    frame,
    inner,
    width,
    valueWidth,
    progress,
    pct,
    session,
    phase,
    bar,
    whisper,
    roundNum,
    cycle,
    audio,
    clock,
    clockBlock,
    intentAscii,
    plainIntent,
    editingIntent,
    template,
    celebrate,
    tick,
    align: template.align ?? 'center',
    themeId,
  };
}

function pushClockRows(lines, ctx, alignOverride) {
  const { clockBlock, inner, width, frame, c, celebrate, tick, align } = ctx;
  const ink = alignOverride ?? align;
  for (const row of clockBlock.rows) {
    lines.push(boxRow(alignRow(row, inner, ink), width, frame, c, celebrate, tick));
  }
}

function pushIntentAscii(lines, ctx, alignOverride) {
  const { intentAscii, inner, width, frame, c, celebrate, tick, align } = ctx;
  const ink = alignOverride ?? align;
  for (const block of intentAscii.blocks) {
    for (const row of block.rows) {
      lines.push(boxRow(alignRow(row, inner, ink), width, frame, c, celebrate, tick));
    }
  }
}

function buildStudioLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, valueWidth, progress, pct, phase, session, roundNum, cycle, audio, whisper, align,
  } = ctx;
  const header = splitRow(
    `${c.accent}${c.b}${c.mark} POMO${c.t}`,
    `${c.mute}${template.label}${c.t} · ${c.label}${c.t}`,
    inner,
  );
  const status = splitRow(
    `${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t} ${c.mute}· ${phase}${c.t}`,
    `${c.mute}round${c.t} ${c.text}${roundNum}/4${c.t}`,
    inner,
  );
  const whisperLine = `${cycle}  ${c.mute}${truncate(whisper, Math.max(8, inner - visibleLen(cycle) - 2))}${c.t}`;
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(header, width, frame, c, celebrate, tick),
    boxRow(alignRow(status, inner, align), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  pushClockRows(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(progressRow(progress, pct, c, inner, 'center', celebrate, tick), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  );
  pushIntentAscii(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    fieldRow('audio', audio, c, width, frame, valueWidth, celebrate, tick),
    boxRow(alignRow(whisperLine, inner, align), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function buildBillboardLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, session, roundNum, whisper, align,
  } = ctx;
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(alignRow(`${c.mute}${truncate(template.caption, Math.max(4, inner - visibleLen(c.label) - 3))}${c.t} · ${c.label}${c.t}`, inner, align), width, frame, c, celebrate, tick),
    boxRow('', width, frame, c, celebrate, tick),
  ];
  pushClockRows(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(progressRow(progress, pct, c, inner, 'center', celebrate, tick), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  );
  pushIntentAscii(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(alignRow(
      splitRow(
        `${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t}`,
        `${c.mute}round ${roundNum}/4${c.t}`,
        inner,
      ),
      inner,
      align,
    ), width, frame, c, celebrate, tick),
    boxRow(alignRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, inner, align), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

/** Receipt barcode, deterministic per intent/total so it never flickers. */
function barcodeRow(seed, c, inner) {
  let h = 2166136261;
  for (const ch of String(seed)) {
    h ^= ch.codePointAt(0);
    h = Math.imul(h, 16777619) >>> 0;
  }
  const serial = String(h % 10000).padStart(4, '0');
  const w = Math.max(10, inner - serial.length - 1);
  let bars = '';
  for (let i = 0; i < w; i++) {
    h = (Math.imul(h, 1103515245) + 12345) >>> 0;
    const v = (h >>> 16) % 4;
    bars += v === 0 ? ' ' : v === 1 ? '▌' : '█';
  }
  return `${c.text}${bars}${c.t} ${c.mute}${serial}${c.t}`;
}

function buildTicketLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, bar, pct, phase, session, audio, clock, whisper,
  } = ctx;
  const stats = `${s.focusToday ?? 0} today  ${s.streakDays ?? 0}d  ${s.focusTotal ?? 0} total`;
  const segment = segmentClockRows(clock, inner, c, celebrate, tick);
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(splitRow(
      `${c.accent}${c.b}POMO${c.t} ${c.mute}${template.label}${c.t}`,
      `${c.label}${c.t}`,
      inner,
    ), width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick, '·'),
    boxRow(`${c.text}${session}${c.t} ${c.mute}· ${phase}${c.t}  ${c.soft}${pct}%${c.t}`, width, frame, c, celebrate, tick),
  ];
  for (const line of segment.rows) {
    lines.push(boxRow(centerRow(line, inner), width, frame, c, celebrate, tick));
  }
  pushIntentAscii(lines, ctx);
  lines.push(
    boxRow(`${c.mute}${stats}${c.t}`, width, frame, c, celebrate, tick),
    boxRow(`${bar}`, width, frame, c, celebrate, tick),
    boxRow(`${c.mute}audio${c.t} ${c.text}${audio}${c.t}`, width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick, '·'),
    boxRow(barcodeRow(`${s.intent || 'pomo'}|${s.focusTotal ?? 0}`, c, inner), width, frame, c, celebrate, tick),
    boxRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function buildDashboardLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, session, roundNum, audio, whisper, clock, align,
  } = ctx;
  const stats = `${s.focusToday ?? 0} today · ${s.streakDays ?? 0}d streak · ${s.focusTotal ?? 0} all`;
  const hud = `${s.hudVisible ? 'on' : 'off'} · ${titleCase(s.watchface)}`;
  const header = splitRow(
    `${c.accent}${c.b}${c.mark} POMO${c.t}`,
    `${c.mute}${template.label}${c.t} · ${c.label}${c.t}`,
    inner,
  );
  const sessionRow = splitRow(
    `${phaseTone(phase, c)} ${c.text}${session}${c.t} · ${phase}`,
    `${c.mute}round ${roundNum}/4${c.t}`,
    inner,
  );
  const clockBar = clockProgressRow(clock, progress, pct, c, inner, celebrate, tick);
  const meta = splitRow(
    `${c.mute}hud${c.t} ${c.text}${truncate(hud, Math.floor(inner * 0.42))}${c.t}`,
    `${c.mute}audio${c.t} ${c.text}${truncate(audio, Math.floor(inner * 0.42))}${c.t}`,
    inner,
  );
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(alignRow(header, inner, align), width, frame, c, celebrate, tick),
    boxRow(alignRow(`${c.accent}${stats}${c.t}`, inner, align), width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick),
    boxRow(alignRow(sessionRow, inner, align), width, frame, c, celebrate, tick),
    boxRow(alignRow(clockBar, inner, align), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  pushIntentAscii(lines, ctx);
  lines.push(
    boxRow(alignRow(meta, inner, align), width, frame, c, celebrate, tick),
    boxRow(alignRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, inner, align), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function buildPhosphorLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, session, whisper, celebrate: cel, tick: t,
  } = ctx;
  const bracket = cel && t % 6 < 2 ? c.glow : c.border;
  const status = `${c.mute}>${c.t} ${phaseTone(phase, c)} ${c.text}${phase}${c.t} ${c.dim}· ${session}${c.t}`;
  const scanline = boxRow(
    centerRow(`${c.dim}${'┈'.repeat(Math.max(8, Math.floor(inner * 0.72)))}${c.t}`, inner),
    width, frame, c, cel, t,
  );
  const cursor = `${cel && t % 2 === 0 ? c.glow : c.mute}▊${c.t}`;
  const lines = [
    frameRule(width, frame, c, cel, t),
    boxRow(centerRow(`${bracket}[ ${c.accent}${c.b}${template.label.toUpperCase()}${c.t} ${c.mute}/ ${c.label.toUpperCase()}${c.t} ${bracket}]${c.t}`, inner), width, frame, c, cel, t),
    boxRow(centerRow(status, inner), width, frame, c, cel, t),
    scanline,
  ];
  pushClockRows(lines, ctx, 'center');
  lines.push(
    scanline,
    boxRow(progressRow(progress, pct, c, inner, 'center', cel, t), width, frame, c, cel, t),
    spacerRow(width, frame, c, cel, t),
  );
  pushIntentAscii(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, cel, t),
    boxRow(centerRow(`${c.mute}>${c.t} ${c.dim}${truncate(promptBody(whisper), inner - 4)}${c.t} ${cursor}`, inner), width, frame, c, cel, t),
    frameFoot(width, frame, c, cel, t),
  );
  return lines;
}

/** Dotted orbit with a satellite at the progress position and a decay trail. */
function orbitRing(progress, c, inner, celebrate, tick) {
  const len = Math.max(12, Math.min(32, inner - 8));
  const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
  const pos = celebrate ? tick % len : Math.min(len - 1, Math.floor(clamped * len));
  const back = (n) => (pos - n + len) % len;
  return Array.from({ length: len }, (_, i) => {
    if (i === pos) return `${c.glow}${c.b}◉${c.t}`;
    if (i === back(1)) return `${c.accent}•${c.t}`;
    if (i === back(2)) return `${c.soft}·${c.t}`;
    return `${c.dim}·${c.t}`;
  }).join('');
}

function buildOrbitLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, session, roundNum, whisper,
  } = ctx;
  const metrics = splitRow(
    `${c.mute}today${c.t} ${c.text}${s.focusToday ?? 0}${c.t}`,
    `${c.mute}streak${c.t} ${c.text}${s.streakDays ?? 0}d${c.t}  ${c.mute}round${c.t} ${c.text}${roundNum}/4${c.t}`,
    inner,
  );
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.soft}${template.label}${c.t} · ${c.label}${c.t}`, inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(orbitRing(progress, c, inner, celebrate, tick), inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(
      `${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t} ${c.mute}· ${phase}${c.t}`,
      inner,
    ), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  pushClockRows(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(progressRow(progress, pct, c, inner, 'center', celebrate, tick), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  );
  pushIntentAscii(lines, ctx, 'center');
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(centerRow(metrics, inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, inner), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

/** ASCII radar scope: rings, cardinal ticks, sweep arm with phosphor decay. */
function radarScopeRows(progress, completed, c, height, celebrate, tick) {
  const H = height % 2 ? height : height + 1;
  const W = H * 2 + 1;
  const cx = (W - 1) / 2;
  const cy = (H - 1) / 2;
  const R = cy;
  const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
  const spin = celebrate ? (tick % 18) / 18 : clamped;
  const cells = new Map();
  const put = (x, y, ch, ink, force = false) => {
    const gx = Math.round(x);
    const gy = Math.round(y);
    if (gx < 0 || gx >= W || gy < 0 || gy >= H) return;
    const key = gy * W + gx;
    if (!force && cells.has(key)) return;
    cells.set(key, `${ink}${ch}`);
  };
  const arm = (turns, ch, ink) => {
    const a = turns * 2 * Math.PI - Math.PI / 2;
    for (let r = 0.6; r <= R; r += 0.3) {
      put(cx + Math.cos(a) * r * 2, cy + Math.sin(a) * r, ch, ink, true);
    }
  };
  arm(spin - 0.08, '·', c.dim);
  arm(spin - 0.04, '•', c.soft);
  arm(spin, '•', c.accent);
  const head = spin * 2 * Math.PI - Math.PI / 2;
  put(cx + Math.cos(head) * R * 2, cy + Math.sin(head) * R, '●', `${c.accent}${c.b}`, true);
  for (let i = 0; i < (Number(completed) || 0) % 4; i++) {
    const a = i * (Math.PI / 2) - Math.PI / 4;
    put(cx + Math.cos(a) * R * 1.1, cy + Math.sin(a) * R * 0.55, '*', c.glow);
  }
  for (const a of [0, Math.PI / 2, Math.PI, (3 * Math.PI) / 2]) {
    put(cx + Math.cos(a) * R * 2, cy + Math.sin(a) * R, '+', c.mute);
  }
  for (let a = 0; a < Math.PI * 2; a += 0.04) {
    put(cx + Math.cos(a) * R * 2, cy + Math.sin(a) * R, '·', c.track);
  }
  put(cx, cy, '+', c.mute);
  const rows = [];
  for (let y = 0; y < H; y++) {
    let row = '';
    for (let x = 0; x < W; x++) row += cells.get(y * W + x) ?? ' ';
    rows.push(`${row}${c.t}`);
  }
  return { rows, width: W, height: H };
}

function buildRadarLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, session, roundNum, audio, whisper, clock, plainIntent,
  } = ctx;
  const header = splitRow(
    `${c.accent}${c.b}${c.mark} POMO${c.t}`,
    `${c.mute}${template.label}${c.t} · ${c.label}${c.t}`,
    inner,
  );
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(header, width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  const sideBySide = inner >= 44;
  const scope = radarScopeRows(progress, s.completedFocusCount, c, sideBySide ? 11 : 9, celebrate, tick);
  if (sideBySide) {
    const rw = inner - scope.width - 3;
    const info = [
      splitRow(`${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t}`, `${c.mute}${phase}${c.t}`, rw),
      '',
      `${c.accent}${c.b}${formatClockDisplay(clock, rw >= 16)}${c.t}`,
      '',
      progressRow(progress, pct, c, rw, 'left', celebrate, tick),
      `${c.mute}round${c.t} ${c.text}${roundNum}/4${c.t}  ${c.dim}${cycleDots(s.completedFocusCount)}${c.t}`,
      '',
      `${c.soft}${truncate(plainIntent, rw)}${c.t}`,
      '',
      `${c.mute}audio${c.t} ${c.text}${truncate(audio, Math.max(4, rw - 6))}${c.t}`,
      `${c.dim}${truncate(whisper, rw)}${c.t}`,
    ];
    for (let i = 0; i < scope.height; i++) {
      lines.push(boxRow(`${scope.rows[i]}   ${info[i] ?? ''}`, width, frame, c, celebrate, tick));
    }
  } else {
    for (const row of scope.rows) {
      lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
    }
    lines.push(
      spacerRow(width, frame, c, celebrate, tick),
      boxRow(centerRow(`${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t} ${c.accent}${c.b}${clock}${c.t}`, inner), width, frame, c, celebrate, tick),
      boxRow(progressRow(progress, pct, c, inner, 'center', celebrate, tick), width, frame, c, celebrate, tick),
      boxRow(centerRow(`${c.soft}${truncate(plainIntent, inner)}${c.t}`, inner), width, frame, c, celebrate, tick),
      boxRow(centerRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, inner), width, frame, c, celebrate, tick),
    );
  }
  lines.push(spacerRow(width, frame, c, celebrate, tick), frameFoot(width, frame, c, celebrate, tick));
  return lines;
}

const MARQUEE_FRAME = ['╔', '╗', '╚', '╝', '═', '║'];

function marqueeLights(inner, c, celebrate, tick) {
  const offset = celebrate ? tick % 2 : 0;
  const count = Math.max(3, Math.floor(inner / 2) - 1);
  const bulbs = [];
  for (let i = 0; i < count; i++) {
    bulbs.push((i + offset) % 2 === 0 ? `${c.glow}●` : `${c.dim}○`);
  }
  return `${bulbs.join(' ')}${c.t}`;
}

function buildMarqueeLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, inner, progress, pct, phase, session, roundNum, clockBlock, intentAscii, whisper,
  } = ctx;
  const frame = MARQUEE_FRAME;
  const lights = boxRow(centerRow(marqueeLights(inner, c, celebrate, tick), inner), width, frame, c, celebrate, tick);
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    lights,
    boxRow(centerRow(`${c.accent}${c.b}${c.mark}  P O M O  ${c.mark}${c.t}`, inner), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  for (const row of clockBlock.rows) {
    lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
  }
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(progressRow(progress, pct, c, inner, 'center', celebrate, tick), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.soft}· NOW SHOWING ·${c.t}`, inner), width, frame, c, celebrate, tick),
  );
  for (const block of intentAscii.blocks) {
    for (const row of block.rows) {
      lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
    }
  }
  const bill = `${phaseTone(phase, c)} ${c.text}${c.b}${session}${c.t}`;
  const billNote = truncate(`· ${phase} · round ${roundNum}/4`, Math.max(4, inner - visibleLen(bill) - 1));
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(centerRow(`${bill} ${c.mute}${billNote}${c.t}`, inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.mute}${truncate(whisper, inner)}${c.t}`, inner), width, frame, c, celebrate, tick),
    lights,
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function zenRakeLine(inner, c, offset) {
  const n = Math.max(4, Math.floor((inner - 4) / 4));
  return `${' '.repeat(offset)}${c.mute}${Array.from({ length: n }, () => '∿∿∿').join('  ')}${c.t}`;
}

function zenStonesPath(progress, c, celebrate, tick) {
  const stones = 12;
  const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
  const filled = Math.round(clamped * stones);
  const pulse = celebrate && tick % 2 === 0;
  return Array.from({ length: stones }, (_, i) => {
    if (i < filled) return `${pulse && i === filled - 1 ? c.glow : c.accent}●`;
    return `${c.track}○`;
  }).join(' ') + c.t;
}

function buildZenLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, inner, progress, phase, session, clockBlock, plainIntent, whisper,
  } = ctx;
  const total = width + 2;
  const row = (text) => padLine(centerRow(text, total), total);
  const drift = celebrate ? tick % 3 : 0;
  const lines = [
    row(''),
    row(`${c.dim}·${c.t}  ${c.mute}○${c.t}  ${c.dim}·${c.t}`),
    row(''),
    row(zenRakeLine(inner, c, drift)),
    row(zenRakeLine(inner, c, (drift + 2) % 4)),
    row(''),
  ];
  for (const line of clockBlock.rows) lines.push(row(line));
  lines.push(
    row(''),
    row(`${c.soft}${truncate(plainIntent, inner)}${c.t}`),
    row(''),
    row(zenStonesPath(progress, c, celebrate, tick)),
    row(''),
    row(zenRakeLine(inner, c, (drift + 1) % 4)),
    row(''),
    row(`${c.soft}${session.toLowerCase()}${c.t} ${c.dim}· ${phase}${c.t}`),
    row(`${c.dim}${truncate(whisper, inner)}${c.t}`),
    row(''),
  );
  return lines;
}

/** Clock digits as split-flap cells with a hinge line across the middle row. */
function flapClockRows(clock, c, inner, celebrate, tick) {
  const chars = [...String(clock || '--:--').replace(/\s/g, '')];
  if (chars.length * 6 - 1 > inner) return null;
  const digitInk = `${c.accent}${c.b}`;
  const hingeInk = celebrate && tick % 4 < 2 ? c.glow : c.border;
  const glyphs = chars.map((ch) => ASCII_BIG[ch] || ASCII_BIG[' ']);
  const rows = [
    chars.map(() => `${c.border}╭───╮${c.t}`).join(' '),
  ];
  for (let r = 0; r < 5; r++) {
    const hinge = r === 2;
    const edge = hinge ? hingeInk : c.border;
    const [l, rr] = hinge ? ['┤', '├'] : ['│', '│'];
    rows.push(glyphs.map((g) => `${edge}${l}${c.t}${digitInk}${(g[r] || '').slice(0, 3).padEnd(3)}${c.t}${edge}${rr}${c.t}`).join(' '));
  }
  rows.push(chars.map(() => `${c.border}╰───╯${c.t}`).join(' '));
  return { rows, width: chars.length * 6 - 1, height: 7 };
}

function leaderRow(label, value, c, inner, ink = null) {
  const lab = `${String(label).toUpperCase()} `.padEnd(8);
  const val = truncate(String(value ?? '—'), Math.max(4, inner - lab.length - 4));
  const dots = Math.max(2, inner - lab.length - visibleLen(val) - 2);
  return `${c.mute}${lab}${c.t}${c.dim}${'┄'.repeat(dots)}${c.t} ${ink || c.text}${val}${c.t}`;
}

function buildFlapboardLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, roundNum, session, clock, whisper, editingIntent,
  } = ctx;
  const status = phase === 'running'
    ? { text: 'BOARDING', ink: c.ok }
    : phase === 'paused'
      ? { text: 'DELAYED', ink: c.warn }
      : { text: 'AT GATE', ink: c.mute };
  const destRaw = editingIntent ? `${edit.intentDraft}▌` : (s.intent || 'press i to set');
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(splitRow(
      `${c.accent}${c.b}${c.mark} POMO${c.t} ${c.mute}departures${c.t}`,
      `${c.mute}${c.label}${c.t}`,
      inner,
    ), width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick, '┄'),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  const flaps = flapClockRows(clock, c, inner, celebrate, tick);
  if (flaps) {
    for (const row of flaps.rows) {
      lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
    }
  } else {
    for (const row of ctx.clockBlock.rows) {
      lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
    }
  }
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick, '┄'),
    boxRow(leaderRow('dest', destRaw.toUpperCase(), c, inner), width, frame, c, celebrate, tick),
    boxRow(leaderRow('time', `${clock} · ${pct}%`, c, inner), width, frame, c, celebrate, tick),
    boxRow(leaderRow('gate', `${session.toUpperCase()} R${roundNum}/4`, c, inner), width, frame, c, celebrate, tick),
    boxRow(leaderRow('status', status.text, c, inner, `${status.ink}${c.b}`), width, frame, c, celebrate, tick),
    boxRow(progressBar(progress, c, inner, celebrate, tick), width, frame, c, celebrate, tick),
    dividerRow(width, frame, c, celebrate, tick, '┄'),
    boxRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function sessionHudLabel(sessionType) {
  const t = (sessionType || '').toLowerCase();
  if (t === 'focus') return 'FOCUS';
  if (t === 'longbreak') return 'LONG';
  return 'BREAK';
}

function segmentClockRows(clock, inner, c, celebrate, tick) {
  const text = String(clock || '--:--').replace(/\s/g, '');
  const ink = celebrate && tick % 4 < 2 ? `${c.glow}${c.b}` : `${c.accent}${c.b}`;
  const rendered = renderAsciiString(text, ASCII_SEGMENT, 1);
  if (rendered.width > inner) {
    return {
      rows: [`${ink}${formatClockDisplay(clock, false)}${c.t}`],
      height: 1,
      fallback: true,
    };
  }
  return {
    rows: colorAsciiRows(rendered.rows, ink, c),
    height: rendered.height,
    fallback: false,
  };
}

function transportRow(phase, c, inner) {
  const restart = `${c.dim}↺${c.t}`;
  const play = phase === 'running' ? `${c.ok}⏸${c.t}` : `${c.ok}▶${c.t}`;
  const skip = `${c.accent}⏭${c.t}`;
  const pause = phase === 'paused' ? `${c.warn}❚❚${c.t}` : `${c.dim}❚❚${c.t}`;
  const stop = `${c.dim}■${c.t}`;
  return centerRow(`${restart}  ${play}  ${skip}     ${pause}  ${stop}`, inner);
}

function remainingRulerRows(progress, c, inner) {
  const ticks = Math.max(10, Math.min(28, inner - 14));
  const pos = Math.round(Math.max(0, Math.min(1, Number(progress) || 0)) * (ticks - 1));
  const track = Array.from({ length: ticks }, (_, i) => (
    i === pos ? `${c.accent}│${c.t}` : `${c.dim}·${c.t}`
  )).join('');
  const arrow = `${c.mute}◀${c.t}${c.dim}${'─'.repeat(Math.max(2, Math.floor((inner - 11 - ticks) / 2)))}${c.t}`;
  const arrowR = `${c.dim}${'─'.repeat(Math.max(2, Math.ceil((inner - 11 - ticks) / 2)))}${c.t}${c.mute}▶${c.t}`;
  const label = `${c.mute}REMAINING${c.t}`;
  const top = centerRow(`${arrow}${label}${arrowR}`, inner);
  const bottom = centerRow(track, inner);
  return [top, bottom];
}

function sheetSessionBox(sessionType, clock, c) {
  const kind = sessionHudLabel(sessionType);
  const hi = `${c.accent}${c.b}`;
  const edge = c.border;
  return [
    `${edge}╭ SESSION ╮${c.t}`,
    `${edge}│${c.t} ${hi}${kind.padEnd(5)}${c.t} ${edge}│${c.t}`,
    `${edge}│${c.t} ${c.mute}T-SET${c.t}  ${edge}│${c.t}`,
    `${edge}│${c.t} ${c.text}${clock}${c.t} ${edge}│${c.t}`,
    `${edge}╰─────────╯${c.t}`,
  ];
}

function sheetStatusLabel(phase) {
  if (phase === 'running') return 'ACTIVE';
  if (phase === 'paused') return 'PAUSED';
  return 'STANDBY';
}

/** Circular watch face: tick ring, session label, sweep hand. */
function watchFaceRows(progress, sessionType, c, height, celebrate, tick) {
  const H = height % 2 ? height : height + 1;
  const W = H * 2 + 1;
  const cx = (W - 1) / 2;
  const cy = (H - 1) / 2;
  const R = cy - 1;
  const clamped = Math.max(0, Math.min(1, Number(progress) || 0));
  const spin = celebrate ? (tick % 24) / 24 : clamped;
  const cells = new Map();
  const put = (x, y, ch, ink, force = false) => {
    const gx = Math.round(x);
    const gy = Math.round(y);
    if (gx < 0 || gx >= W || gy < 0 || gy >= H) return;
    const key = gy * W + gx;
    if (!force && cells.has(key)) return;
    cells.set(key, `${ink}${ch}`);
  };
  for (let a = 0; a < Math.PI * 2; a += Math.PI / 30) {
    put(cx + Math.cos(a) * R * 2, cy + Math.sin(a) * R, '·', c.soft);
  }
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * 2 * Math.PI - Math.PI / 2;
    const major = i % 3 === 0;
    const r0 = major ? R * 0.82 : R * 0.9;
    put(cx + Math.cos(a) * r0 * 2, cy + Math.sin(a) * r0, major ? '│' : '·', major ? c.soft : c.mute);
  }
  const head = spin * 2 * Math.PI - Math.PI / 2;
  for (let r = 0.2; r <= R; r += 0.35) {
    put(cx + Math.cos(head) * r * 2, cy + Math.sin(head) * r, '·', c.soft, true);
  }
  put(cx + Math.cos(head) * R * 2, cy + Math.sin(head) * R, '│', `${c.accent}${c.b}`, true);
  put(cx, cy, '◉', celebrate && tick % 4 < 2 ? c.glow : c.accent, true);
  const label = sessionHudLabel(sessionType);
  const labelInk = `${c.accent}${c.b}`;
  const labelStart = Math.max(0, Math.floor(cx - label.length / 2));
  for (let i = 0; i < label.length; i++) {
    put(labelStart + i, Math.max(0, cy - R * 0.55), label[i], labelInk, true);
  }
  const rows = [];
  for (let y = 0; y < H; y++) {
    let row = '';
    for (let x = 0; x < W; x++) row += cells.get(y * W + x) ?? ' ';
    rows.push(`${row}${c.t}`);
  }
  return { rows, width: W, height: H };
}

function buildSheetLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, roundNum, clock, clockBlock, whisper,
  } = ctx;
  const sheetNo = `SHEET ${String(roundNum).padStart(2, '0')} / 04`;
  const mins = Math.max(0, Math.round((Number(s.remainingSeconds) || 0) / 60));
  const status = sheetStatusLabel(phase);
  const sideBox = inner >= 46;
  const box = sheetSessionBox(s.sessionType, clock, c);
  const titleLeft = `${c.accent}${pct}%${c.t}`;
  const titleRight = sideBox ? '' : `${c.mute}${sheetNo}${c.t}`;
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(splitRow(titleLeft, titleRight, inner), width, frame, c, celebrate, tick),
  ];
  if (sideBox) {
    const leftW = inner - box[0].length - 2;
    for (let i = 0; i < box.length; i++) {
      const left = i === 1
        ? `${c.mute}${sheetNo}${c.t}`
        : i === 2
          ? `${c.accent}${c.b}POMO · TIMER${c.t}`
          : '';
      lines.push(boxRow(splitRow(left, box[i], inner), width, frame, c, celebrate, tick));
    }
  } else {
    lines.push(
      boxRow(`${c.mute}${sheetNo}${c.t}`, width, frame, c, celebrate, tick),
      boxRow(`${c.accent}${c.b}POMO · TIMER${c.t}`, width, frame, c, celebrate, tick),
      ...box.map((row) => boxRow(padLine(row, inner), width, frame, c, celebrate, tick)),
    );
  }
  lines.push(spacerRow(width, frame, c, celebrate, tick));
  for (const row of clockBlock.rows) {
    lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
  }
  for (const row of remainingRulerRows(progress, c, inner)) {
    lines.push(boxRow(row, width, frame, c, celebrate, tick));
  }
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(splitRow(
      `${phaseTone(phase, c)} ${c.text}${c.b}${status}${c.t}`,
      `${c.mute}${s.completedFocusCount ?? 0}${c.t}  ${c.soft}${pct}%${c.t}  ${c.text}${mins}'${c.t}`,
      inner,
    ), width, frame, c, celebrate, tick),
    boxRow(transportRow(phase, c, inner), width, frame, c, celebrate, tick),
    boxRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

function buildLcdLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, inner, progress, pct, phase, whisper, plainIntent,
  } = ctx;
  const segment = segmentClockRows(ctx.clock, inner, c, celebrate, tick);
  const kind = sessionHudLabel(s.sessionType);
  const totalRow = width + 2;
  const row = (text) => padLine(centerRow(text, totalRow), totalRow);
  const barW = segment.fallback ? totalRow - 8 : Math.min(segment.width + 6, totalRow - 6);
  const hr = row(`${c.dim}${'─'.repeat(barW)}${c.t}`);
  const lines = [
    row(''),
    row(splitRow(`${c.accent}${c.b}${kind}${c.t}`, `${c.soft}${pct}%${c.t}`, totalRow - 4)),
    hr,
    row(''),
  ];
  for (const line of segment.rows) lines.push(row(line));
  lines.push(
    row(''),
    row(progressBar(progress, c, barW, celebrate, tick)),
    hr,
    row(transportRow(phase, c, totalRow - 4)),
    row(`${c.soft}${truncate(plainIntent, totalRow - 4)}${c.t}`),
    row(''),
  );
  return lines;
}

function buildWatchLayout(s, edit, template, themeId, width, celebrate, tick) {
  const ctx = cardContext(s, edit, template, themeId, width, celebrate, tick);
  const {
    c, frame, inner, progress, pct, phase, clock, whisper, plainIntent,
  } = ctx;
  const face = watchFaceRows(progress, s.sessionType, c, inner >= 40 ? 13 : 11, celebrate, tick);
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
  ];
  for (const row of face.rows) {
    lines.push(boxRow(centerRow(row, inner), width, frame, c, celebrate, tick));
  }
  lines.push(
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.accent}${c.b}${formatClockDisplay(clock, inner >= 36)}${c.t}`, inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(`${phaseTone(phase, c)}  ${c.soft}${pct}%${c.t}`, inner), width, frame, c, celebrate, tick),
    spacerRow(width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.text}${truncate(plainIntent, inner - 2)}${c.t}`, inner), width, frame, c, celebrate, tick),
    boxRow(transportRow(phase, c, inner), width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.dim}${truncate(whisper, inner)}${c.t}`, inner), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  );
  return lines;
}

const TUI_LAYOUT_BUILDERS = {
  studio: buildStudioLayout,
  billboard: buildBillboardLayout,
  ticket: buildTicketLayout,
  dashboard: buildDashboardLayout,
  phosphor: buildPhosphorLayout,
  orbit: buildOrbitLayout,
  radar: buildRadarLayout,
  marquee: buildMarqueeLayout,
  zen: buildZenLayout,
  flapboard: buildFlapboardLayout,
  sheet: buildSheetLayout,
  lcd: buildLcdLayout,
  watch: buildWatchLayout,
};

function buildCardLines(s, edit, templateId, themeId, width, celebrate, tick) {
  const template = tuiTemplate(templateId);
  const build = TUI_LAYOUT_BUILDERS[template.layout] || buildStudioLayout;
  return build(s, edit, template, themeId, width, celebrate, tick);
}

function buildHelpCard(templateId, themeId, width) {
  const c = tuiPalette(themeId);
  const frame = c.frame;
  const inner = width - 2;
  const rows = [
    ['space', 'start / pause timer'],
    ['a', 'play / pause track'],
    ['i', 'edit intent'],
    ['T', 'cycle template (layout)'],
    ['t', 'cycle theme (colors)'],
    ['n', 'skip session'],
    ['h', 'toggle HUD (terminal keeps focus)'],
    ['4', 'stats panel'],
    ['?', 'this help'],
    ['q', 'quit'],
  ];
  const lines = [
    frameRule(width, frame, c),
    boxRow(`${c.accent}${c.b}${c.mark} HELP${c.t}`, width, frame, c),
    boxRow('', width, frame, c),
  ];
  for (const [key, desc] of rows) {
    lines.push(boxRow(
      `${c.accent}${key.padEnd(6)}${c.t} ${c.text}${desc}${c.t}`,
      width,
      frame,
      c,
    ));
  }
  lines.push(boxRow(`${c.accent}${c.b}templates (T)${c.t}`, width, frame, c));
  for (const preset of TUI_TEMPLATES) {
    lines.push(boxRow(
      `${c.accent}${preset.label.padEnd(10)}${c.t} ${c.dim}${preset.caption}${c.t}`,
      width,
      frame,
      c,
    ));
  }
  lines.push(boxRow('', width, frame, c), boxRow(`${c.accent}${c.b}themes (t)${c.t}`, width, frame, c));
  for (const id of TUI_THEME_IDS) {
    const theme = TUI_THEMES[id];
    lines.push(boxRow(
      `${c.accent}${theme.label.padEnd(10)}${c.t} ${c.dim}${theme.tagline}${c.t}`,
      width,
      frame,
      c,
    ));
  }
  lines.push(
    boxRow('', width, frame, c),
    boxRow(centerRow(`${c.dim}? or esc close${c.t}`, inner), width, frame, c),
    frameFoot(width, frame, c),
  );
  return lines;
}

function buildStatsCard(s, templateId, themeId, width, celebrate, tick) {
  const c = tuiPalette(themeId);
  const frame = c.frame;
  const inner = width - 2;
  const roundNum = ((Number(s.completedFocusCount) || 0) % 4) + 1;
  const pct = Math.round((Number(s.progress) || 0) * 100);
  const elapsed = Math.max(0, (Number(s.totalSeconds) || 0) - (Number(s.remainingSeconds) || 0));
  const lines = [
    frameRule(width, frame, c, celebrate, tick),
    boxRow(`${c.accent}${c.b}${c.mark} STATS${c.t}`, width, frame, c),
    boxRow('', width, frame, c),
    boxRow(statRow('today', `${s.focusToday ?? 0} focus`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('streak', `${s.streakDays ?? 0} days`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('total', `${s.focusTotal ?? 0} focus`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('round', `${roundNum} of 4`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('done', `${s.completedFocusCount ?? 0} blocks`, c, inner), width, frame, c, celebrate, tick),
    boxRow('', width, frame, c, celebrate, tick),
    boxRow(statRow('session', `${sessionLabel(s.sessionType)} · ${s.phase || 'idle'}`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('clock', `${s.clock || '--:--'} (${pct}%)`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('elapsed', `${formatClock(elapsed)} / ${formatClock(s.totalSeconds)}`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('hud', `${s.hudVisible ? 'visible' : 'hidden'} · ${titleCase(s.watchface)}`, c, inner), width, frame, c, celebrate, tick),
    boxRow(statRow('audio', truncate(audioLine(s, celebrate, tick), inner - 8), c, inner), width, frame, c, celebrate, tick),
    boxRow('', width, frame, c, celebrate, tick),
    boxRow(centerRow(`${c.dim}4 or esc close${c.t}`, inner), width, frame, c, celebrate, tick),
    frameFoot(width, frame, c, celebrate, tick),
  ];
  return lines;
}

function buildMessageCard(title, body, themeId, width) {
  const c = tuiPalette(themeId);
  const frame = c.frame;
  const inner = width - 2;
  return [
    frameRule(width, frame, c),
    boxRow(`${c.accent}${c.b}${c.mark} POMO${c.t} ${c.mute}· ${c.accent}${c.label}${c.t}`, width, frame, c),
    boxRow(centerRow(`${c.text}${title}${c.t}`, inner), width, frame, c),
    boxRow(centerRow(`${c.soft}${truncate(body, inner)}${c.t}`, inner), width, frame, c),
    frameFoot(width, frame, c),
  ];
}

function keybar(edit, c, cols) {
  const text = edit?.intentMode
    ? 'enter save · esc cancel · empty clears'
    : edit?.overlay === 'help'
      ? '? help · esc close'
      : edit?.overlay === 'stats'
        ? '4 stats · esc close'
        : 'space · a · i · T template · t theme · n · h HUD · 4 · ? · q';
  const shown = truncate(text, Math.max(1, cols - 2));
  const pad = Math.max(0, Math.floor((cols - visibleLen(shown)) / 2));
  return `${c.key}${' '.repeat(pad)}${shown}${c.t}`;
}

function composeTuiFrame(cardLines, templateId, themeId, celebrate, tick, hint = null) {
  const template = tuiTemplate(templateId);
  const { cols, rows } = termSize();
  const c = tuiPalette(themeId);
  const lineWidth = Math.max(...cardLines.map(visibleLen));
  const startRow = Math.max(2, Math.floor((rows - cardLines.length) / 2));
  const startCol = Math.max(1, Math.floor((cols - lineWidth) / 2));
  const haloPad = 1;
  const haloRow0 = Math.max(1, startRow - haloPad);
  const haloRow1 = Math.min(rows, startRow + cardLines.length - 1 + haloPad);
  const haloCol0 = Math.max(1, startCol - haloPad);
  const haloWidth = Math.min(cols - haloCol0 + 1, lineWidth + haloPad * 2);
  const chrome = template.chrome ?? 'full';

  let buf = '\x1b[H\x1b[2J';
  for (let y = 1; y <= rows; y++) {
    if (y > 1) buf += '\n';
    buf += backgroundRow(cols, c);
  }

  if (chrome === 'full' || chrome === 'minimal') {
    if (chrome === 'full') {
      const shadowCol = Math.min(cols, haloCol0 + 1);
      const shadowWidth = Math.min(cols - shadowCol + 1, haloWidth);
      for (let y = haloRow0 + 1; y <= Math.min(rows, haloRow1 + 1); y++) {
        buf += cursorAt(y, shadowCol);
        buf += `${c.shadow()}${' '.repeat(shadowWidth)}${c.r}`;
      }
    }
    const haloBg = celebrate && tick % 6 < 2 ? c.margin() : c.halo();
    for (let y = haloRow0; y <= haloRow1; y++) {
      buf += cursorAt(y, haloCol0);
      buf += `${haloBg}${' '.repeat(haloWidth)}${c.r}`;
    }
  }

  const cardBg = c.card();
  for (let i = 0; i < cardLines.length; i++) {
    buf += cursorAt(startRow + i, startCol);
    buf += `${cardBg}${cardLines[i]}${c.r}`;
  }

  const footer = hint || keybar(null, c, cols);
  buf += cursorAt(rows, 1);
  buf += `${c.canvas()}${footer}\x1b[K${c.r}`;
  return `${buf}\n`;
}

function renderTui(s, edit = null, templateId = 'studio', themeId = 'ember', celebrate = false) {
  const template = tuiTemplate(templateId);
  const { cols } = termSize();
  const c = tuiPalette(themeId);
  const tick = celebrate ? tuiTick() : 0;
  const width = cardWidth(cols, template);
  let card;
  if (edit?.overlay === 'help') card = buildHelpCard(templateId, themeId, width);
  else if (edit?.overlay === 'stats') card = buildStatsCard(s, templateId, themeId, width, celebrate, tick);
  else card = buildCardLines(s, edit, templateId, themeId, width, celebrate, tick);
  const footer = (edit?.intentMode || edit?.overlay) ? keybar(edit, c, cols) : null;
  return composeTuiFrame(card, templateId, themeId, celebrate, tick, footer);
}

function renderTuiMessage(title, body, hint = 'q quit', templateId = 'studio', themeId = 'ember') {
  const template = tuiTemplate(templateId);
  const card = buildMessageCard(title, body, themeId, cardWidth(termSize().cols, template));
  const c = tuiPalette(themeId);
  return composeTuiFrame(card, templateId, themeId, false, 0, `${c.key} ${hint}${c.t}`);
}

function runTui() {
  if (!process.stdin.isTTY) {
    printStatus([]);
    return;
  }

  let stopping = false;
  let drawTimer = null;
  let burstTimer = null;
  let fsWatcher = null;
  let usedAltScreen = false;
  let intentMode = false;
  let intentDraft = '';
  let overlay = null;
  let snapshot = null;
  let snapshotAt = 0;
  let paintedFingerprint = '';
  const tuiPrefs = loadTuiPrefs();
  let templateId = tuiPrefs.template;
  let themeId = tuiPrefs.theme;
  let celebrateUntil = 0;
  let prevCelebrateState = null;

  const celebrating = () => Date.now() < celebrateUntil;

  const pulseCelebrate = () => {
    celebrateUntil = Date.now() + CELEBRATE_MS;
    scheduleDraw();
  };

  const cleanup = (code = 0) => {
    if (stopping) return;
    stopping = true;
    if (drawTimer) clearInterval(drawTimer);
    if (burstTimer) clearInterval(burstTimer);
    fsWatcher?.close();
    unwatchFile(STATE_FILE);
    if (usedAltScreen) process.stdout.write('\x1b[?1049l\x1b[?25h\x1b[0m');
    else process.stdout.write('\x1b[?25h\x1b[0m');
    process.stdin.setRawMode?.(false);
    process.stdin.pause();
    process.exit(code);
  };

  const syncPaint = process.stdout.isTTY && process.env.TERM !== 'dumb';

  const paint = (frame) => {
    if (syncPaint) process.stdout.write('\x1b[?2026h');
    process.stdout.write(frame);
    if (syncPaint) process.stdout.write('\x1b[?2026l');
  };

  const refreshSnapshot = () => {
    const fresh = tryReadState();
    if (fresh) {
      snapshot = fresh;
      snapshotAt = Date.now();
    }
    return snapshot;
  };

  const trackCelebrate = (s) => {
    if (!s) return;
    const shouldCelebrate = prevCelebrateState && detectCelebrate(prevCelebrateState, s);
    prevCelebrateState = celebrateSnapshot(s);
    if (shouldCelebrate) pulseCelebrate();
  };

  const displayState = () => {
    if (!snapshot) return null;
    return extrapolateState(snapshot, Date.now() - snapshotAt);
  };

  const uiEdit = () => {
    if (intentMode) return { intentMode: true, intentDraft, overlay: null };
    if (overlay) return { overlay };
    return null;
  };

  const draw = (force = false) => {
    if (force || !snapshot) refreshSnapshot();
    const edit = uiEdit();
    const s = displayState();
    trackCelebrate(s);
    if (!s) {
      paintedFingerprint = '';
      paint(renderTuiMessage('waiting for Pomo…', 'Start the app, then this panel updates live.', 'q quit', templateId, themeId));
      return;
    }
    const celebratingNow = celebrating();
    const fingerprint = stateFingerprint(s, edit, templateId, themeId, termSize(), celebratingNow);
    if (!force && fingerprint === paintedFingerprint) return;
    paintedFingerprint = fingerprint;
    paint(renderTui(s, edit, templateId, themeId, celebratingNow));
  };

  const burstRefresh = () => {
    if (burstTimer) clearInterval(burstTimer);
    const started = stateFingerprint(displayState(), null, templateId, themeId);
    let attempts = 0;
    burstTimer = setInterval(() => {
      draw(true);
      attempts += 1;
      const next = stateFingerprint(displayState(), null, templateId, themeId);
      if (next !== started || attempts >= 30) {
        clearInterval(burstTimer);
        burstTimer = null;
      }
    }, 50);
  };

  const optimistic = (patch) => {
    if (!snapshot) return;
    snapshot = { ...snapshot, ...patch };
    snapshotAt = Date.now();
    draw(true);
  };

  const act = (path, optimisticPatch = null) => {
    if (optimisticPatch) optimistic(optimisticPatch);
    if (!send(path, { soft: true })) {
      paintedFingerprint = '';
      paint(renderTuiMessage('could not reach Pomo', 'Try: pomo install', 'q quit', templateId, themeId));
      return;
    }
    burstRefresh();
  };

  const saveUiPrefs = () => saveTuiPrefs({ template: templateId, theme: themeId });

  const cycleTemplate = () => {
    const idx = TUI_TEMPLATE_IDS.indexOf(templateId);
    templateId = TUI_TEMPLATE_IDS[(idx + 1) % TUI_TEMPLATE_IDS.length];
    saveUiPrefs();
    pulseCelebrate();
    draw(true);
  };

  const cycleTheme = () => {
    const idx = TUI_THEME_IDS.indexOf(themeId);
    themeId = TUI_THEME_IDS[(idx + 1) % TUI_THEME_IDS.length];
    saveUiPrefs();
    pulseCelebrate();
    draw(true);
  };

  const leaveIntentMode = (save) => {
    intentMode = false;
    process.stdout.write('\x1b[?25l');
    if (save) {
      const text = intentDraft.trim();
      optimistic({ intent: text });
      act(text ? `intent${query({ text })}` : 'intent/clear');
    } else {
      intentDraft = '';
      draw(true);
    }
  };

  const enterIntentMode = () => {
    overlay = null;
    refreshSnapshot();
    intentDraft = snapshot?.intent || '';
    intentMode = true;
    process.stdout.write('\x1b[?25h');
    draw(true);
  };

  const toggleOverlay = (mode) => {
    if (intentMode) return;
    overlay = overlay === mode ? null : mode;
    draw(true);
  };

  const toggleAudio = () => {
    refreshSnapshot();
    if (!snapshot?.audioURL) return;
    act(
      snapshot.audioPlaying ? 'audio/pause' : 'audio/play',
      { audioPlaying: !snapshot.audioPlaying },
    );
  };

  const toggleTimer = () => {
    refreshSnapshot();
    if (!snapshot) return;
    const willRun = snapshot.phase !== 'running';
    act('toggle', { phase: willRun ? 'running' : 'paused' });
  };

  if (process.stdout.isTTY && process.env.TERM !== 'dumb') {
    process.stdout.write('\x1b[?1049h\x1b[?25l');
    usedAltScreen = true;
  } else {
    process.stdout.write('\x1b[?25l');
  }

  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding('utf8');
  process.stdin.on('data', (key) => {
    if (stopping) return;

    if (intentMode) {
      if (key === '\u0003') cleanup();
      else if (key === '\u001b' || key === '\u001b\u001b') leaveIntentMode(false);
      else if (key === '\r' || key === '\n') leaveIntentMode(true);
      else if (key === '\u007f' || key === '\b') {
        intentDraft = intentDraft.slice(0, -1);
        draw(true);
      } else if (key.length === 1 && key >= ' ' && key <= '~') {
        intentDraft += key;
        draw(true);
      }
      return;
    }

    if (key === '\u0003' || key === 'q' || key === 'Q') cleanup();
    else if (key === '\u001b' || key === '\u001b\u001b') {
      if (overlay) {
        overlay = null;
        draw(true);
      } else {
        cleanup();
      }
    }
    else if (key === ' ') toggleTimer();
    else if (key === 'a' || key === 'A') toggleAudio();
    else if (key === 'T') cycleTemplate();
    else if (key === 't') cycleTheme();
    else if (key === 'i' || key === 'I') enterIntentMode();
    else if (key === 's' || key === 'S') act('start', { phase: 'running' });
    else if (key === 'p' || key === 'P') act('pause', { phase: 'paused' });
    else if (key === 'r' || key === 'R') act('reset');
    else if (key === 'n' || key === 'N') act('skip');
    else if (key === 'h' || key === 'H') {
      const show = !snapshot?.hudVisible;
      act(show ? 'hud/peek' : 'hide', { hudVisible: show });
    }
    else if (key === '?' || key === '/') toggleOverlay('help');
    else if (key === '4') toggleOverlay('stats');
  });

  try {
    fsWatcher = watch(dirname(STATE_FILE), (_, file) => {
      if (file === basename(STATE_FILE)) draw(true);
    });
  } catch {
    /* fall back to watchFile below */
  }
  watchFile(STATE_FILE, { interval: 100 }, () => draw(true));

  const scheduleDraw = () => {
    if (drawTimer) clearInterval(drawTimer);
    const ms = celebrating() ? 120 : 500;
    let wasCelebrating = celebrating();
    drawTimer = setInterval(() => {
      draw(false);
      const nowCelebrating = celebrating();
      if (nowCelebrating !== wasCelebrating) {
        wasCelebrating = nowCelebrating;
        scheduleDraw();
      }
    }, ms);
  };

  scheduleDraw();
  process.stdout.on('resize', () => draw(true));
  process.on('SIGINT', () => cleanup(130));
  process.on('SIGTERM', () => cleanup(143));
  draw(true);
}

// ─── install ────────────────────────────────────────────────────────────────

async function latestDmg() {
  const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=30`, {
    headers: { 'User-Agent': 'pomo-cli', Accept: 'application/vnd.github+json' },
  });
  if (!res.ok) die(`GitHub API returned ${res.status} ${res.statusText}.`);
  const releases = await res.json();
  // Releases come back newest-first; take the newest one carrying a .dmg.
  for (const rel of releases) {
    if (rel.draft) continue;
    const dmgs = (rel.assets || []).filter((a) => a.name.toLowerCase().endsWith('.dmg'));
    if (!dmgs.length) continue;
    // Prefer the native, unversioned `Pomo.dmg`; otherwise take the first .dmg.
    const asset = dmgs.find((a) => a.name === 'Pomo.dmg') || dmgs[0];
    return { tag: rel.tag_name, name: rel.name, asset };
  }
  return null;
}

function sh(file, args) {
  return execFileSync(file, args, { encoding: 'utf8' });
}

async function install(args) {
  requireMac();
  const dryRun = hasFlag(args, 'dry-run');

  process.stderr.write('Finding the latest Pomo .dmg…\n');
  const found = await latestDmg();
  if (!found) die(`no .dmg asset found in any ${REPO} release yet.`);
  const { tag, asset } = found;
  const sizeMB = (asset.size / 1e6).toFixed(1);
  console.log(`Latest: ${asset.name}  (${tag}, ${sizeMB} MB)`);
  console.log(`  ${asset.browser_download_url}`);

  if (dryRun) {
    console.log('  → would install to /Applications/Pomo.app (dry run, nothing downloaded)');
    return;
  }

  // 1. Download.
  const dir = mkdtempSync(join(tmpdir(), 'pomo-install-'));
  const dmgPath = join(dir, asset.name);
  process.stderr.write('Downloading…\n');
  const dl = await fetch(asset.browser_download_url, { headers: { 'User-Agent': 'pomo-cli' } });
  if (!dl.ok) die(`download failed: ${dl.status} ${dl.statusText}`);
  writeFileSync(dmgPath, Buffer.from(await dl.arrayBuffer()));

  // 2. Mount.
  process.stderr.write('Mounting…\n');
  const attach = sh('hdiutil', ['attach', dmgPath, '-nobrowse', '-noverify', '-readonly']);
  const mount = attach
    .trim()
    .split('\n')
    .map((l) => l.split('\t').pop().trim())
    .filter((p) => p.startsWith('/Volumes/'))
    .pop();
  if (!mount) die('could not determine the mounted volume.');

  try {
    const app = readdirSync(mount).find((n) => n.endsWith('.app'));
    if (!app) die('no .app inside the disk image.');

    // 3. Copy into /Applications (fall back to ~/Applications if not writable).
    let appsDir = '/Applications';
    let dest = join(appsDir, app);
    try {
      rmSync(dest, { recursive: true, force: true });
      sh('ditto', [join(mount, app), dest]);
    } catch (e) {
      if (e && (e.code === 'EACCES' || e.code === 'EPERM' || /Permission denied/.test(String(e)))) {
        appsDir = join(homedir(), 'Applications');
        dest = join(appsDir, app);
        process.stderr.write('/Applications not writable — installing to ~/Applications instead.\n');
        rmSync(dest, { recursive: true, force: true });
        sh('mkdir', ['-p', appsDir]);
        sh('ditto', [join(mount, app), dest]);
      } else {
        throw e;
      }
    }

    // 4. Clear the download quarantine so it launches without a Gatekeeper prompt.
    try {
      sh('xattr', ['-dr', 'com.apple.quarantine', dest]);
    } catch {
      /* best effort */
    }

    console.log(`Installed ${app} → ${dest}`);
    if (hasFlag(args, 'open')) {
      sh('open', [dest]);
      console.log('Launched.');
    } else {
      console.log('Launch it with:  pomo show   (or: open -a Pomo)');
    }
  } finally {
    // 5. Always unmount.
    try {
      sh('hdiutil', ['detach', mount, '-quiet']);
    } catch {
      /* best effort */
    }
  }
}

// ─── login / cookie import (local browser data) ─────────────────────────────

/** Detected Chromium-family browser profiles, for cookie import. */
function browserProfiles() {
  // Most-common first, so the browsers people actually use lead the picker.
  const bases = [
    ['chrome', 'Google/Chrome'],
    ['edge', 'Microsoft Edge'],
    ['brave', 'BraveSoftware/Brave-Browser'],
    ['chromium', 'Chromium'],
  ];
  const out = [];
  for (const [browser, base] of bases) {
    const ls = join(homedir(), 'Library', 'Application Support', base, 'Local State');
    if (!existsSync(ls)) continue;
    try {
      const cache = JSON.parse(readFileSync(ls, 'utf8'))?.profile?.info_cache ?? {};
      for (const [dir, info] of Object.entries(cache)) {
        out.push({ browser, dir, name: info?.name ?? '?' });
      }
    } catch {
      /* skip unreadable */
    }
  }
  return out;
}

function listProfiles() {
  const ps = browserProfiles();
  if (!ps.length) return console.log('(no Chromium browser profiles found)');
  for (const p of ps) console.log(`  ${p.browser.padEnd(9)} ${p.dir.padEnd(14)} ${p.name}`);
}

async function pickProfile(ps) {
  const rl = createInterface({ input: process.stdin, output: process.stderr });
  ps.forEach((p, i) => process.stderr.write(`  ${i + 1}. ${p.browser} · ${p.name} (${p.dir})\n`));
  const ans = await new Promise((res) => rl.question('Import cookies from which profile? [number] ', res));
  rl.close();
  return ps[parseInt(ans, 10) - 1];
}

async function loginCmd(args) {
  const sub = (args[0] || '').toLowerCase();
  switch (sub) {
    case 'profiles':
      return listProfiles();
    case 'account': {
      const n = parseInt(args[1], 10);
      if (!Number.isInteger(n)) die('usage: pomo login account <n>');
      return send(`login/account/${n}`);
    }
    case 'import': {
      let browser = takeFlag(args, 'browser');
      let profile = takeFlag(args, 'profile');
      if (!browser) {
        const ps = browserProfiles();
        if (!ps.length) die('no Chromium browser profiles found to import from.');
        if (!process.stdin.isTTY) {
          console.log('Pick one and pass --browser/--profile:');
          listProfiles();
          return;
        }
        const choice = await pickProfile(ps);
        if (!choice) die('no profile selected.');
        browser = choice.browser;
        profile = choice.dir;
      }
      return send(`login/import${query({ browser, profile })}`);
    }
    default:
      return send('login');
  }
}

// ─── favorites (list reads state; mutations go over the scheme) ──────────────

function favorites(args) {
  const sub = (args[0] || 'list').toLowerCase();
  switch (sub) {
    case 'list': {
      const favs = readState().favorites || [];
      if (!favs.length) return console.log('(no favorites yet)');
      favs.forEach((f, i) => console.log(`${i + 1}. ${f.title}  —  ${f.url}`));
      return;
    }
    case 'add': {
      const url = args[1];
      if (!url) die('usage: pomo fav add <url> [title…]');
      const title = args.slice(2).join(' ') || undefined;
      return send(`favorite/add${query({ url, title })}`);
    }
    case 'rename': {
      const n = parseInt(args[1], 10);
      const title = args.slice(2).join(' ');
      if (!Number.isInteger(n) || !title) die('usage: pomo fav rename <n> <title…>');
      return send(`favorite/update/${n}${query({ title })}`);
    }
    case 'url': {
      const n = parseInt(args[1], 10);
      const url = args[2];
      if (!Number.isInteger(n) || !url) die('usage: pomo fav url <n> <url>');
      return send(`favorite/update/${n}${query({ url })}`);
    }
    case 'move': {
      const from = parseInt(args[1], 10);
      const to = parseInt(args[2], 10);
      if (!Number.isInteger(from) || !Number.isInteger(to)) die('usage: pomo fav move <from> <to>');
      return send(`favorite/move/${from}/${to}`);
    }
    case 'set':
    case 'replace': {
      const source = args[1];
      if (!source) die('usage: pomo fav set <json-file|json|->');
      const raw = source === '-'
        ? readFileSync(0, 'utf8')
        : existsSync(source)
          ? readFileSync(source, 'utf8')
          : args.slice(1).join(' ');
      let items;
      try {
        items = JSON.parse(raw);
      } catch (error) {
        die(`invalid favorites JSON: ${error.message}`);
      }
      if (!Array.isArray(items)) die('favorites JSON must be an array of { "title": "...", "url": "..." } objects');
      const normalized = items.map((item, index) => {
        if (!item || typeof item !== 'object') die(`favorite ${index + 1} must be an object`);
        const url = String(item.url || '').trim();
        if (!url) die(`favorite ${index + 1} is missing url`);
        const title = String(item.title || '').trim();
        return { title: title || url, url };
      });
      return send(`favorite/set${query({ items: JSON.stringify(normalized) })}`);
    }
    case 'clear':
      return send('favorite/clear');
    case 'play': {
      const n = parseInt(args[1], 10);
      if (!Number.isInteger(n)) die('usage: pomo fav play <n>');
      return send(`favorite/play/${n}`);
    }
    case 'remove': {
      const n = parseInt(args[1], 10);
      if (!Number.isInteger(n)) die('usage: pomo fav remove <n>');
      return send(`favorite/remove/${n}`);
    }
    default:
      die(`unknown fav command: ${sub}`);
  }
}

function sessionKey(input) {
  switch ((input || '').toLowerCase()) {
    case 'focus':
    case 'work':
      return 'focus';
    case 'short':
    case 'break':
    case 'shortbreak':
    case 'short-break':
      return 'break';
    case 'long':
    case 'longbreak':
    case 'long-break':
      return 'long';
    default:
      return null;
  }
}

function sessionAudio(args) {
  const type = sessionKey(args[0]);
  if (!type) die('usage: pomo audio session <focus|break|long> <favorite#|url|clear>');

  const value = args[1];
  if (!value) die('usage: pomo audio session <focus|break|long> <favorite#|url|clear>');
  if (value.toLowerCase() === 'clear') return send(`audio/session/${type}/clear`);

  let url = value;
  if (/^\d+$/.test(value)) {
    const favorite = (readState().favorites || [])[Number(value) - 1];
    if (!favorite) die(`no favorite #${value}`);
    url = favorite.url;
  }
  if (!/^https?:\/\//i.test(url)) die('session audio must be a favorite number, URL, or clear');
  return send(`audio/session/${type}${query({ url })}`);
}

// ─── help ─────────────────────────────────────────────────────────────────

function help() {
  console.log(`pomo — control & install the Pomo macOS HUD timer

Usage: pomo <command> [args]

Timer
  tui                    open the live terminal UI
  screenshot --out <png> [--template id] [--theme id] [--cols n] [--rows n]
  status [--json]        one-shot status (\`pomo\` alone opens the TUI in a terminal)
  start | pause | toggle | reset | skip
  session <focus|short|long>
  duration <minutes>

Intent
  intent <text…>         set what you're working on
  intent clear           clear it

Audio / video
  audio <url>            play a YouTube/stream link
  audio <play|pause|stop|next|prev>
  audio session <focus|break|long> <favorite#|url|clear>
  volume <0-100>
  video <show|hide|toggle|page|player|browser>

Favorites
  fav                    list saved stations
  fav add <url> [title…]
  fav rename <n> <title…>
  fav url <n> <url>
  fav move <from> <to>
  fav set <json-file|json|->
  fav play <n>
  fav remove <n>
  fav clear

Window & app
  show | hide | hud      summon / dismiss / toggle the HUD
  menu                   open the menu-bar popover
  face <name>            switch watchface
  settings | stats       open the Settings / Stats window
  login                  audio sign-in (YouTube)
  login import [--browser b] [--profile p]   import browser cookies (ad-free)
  login profiles         list detected browser profiles
  login account <n> | logout
  install [--dry-run] [--open]   download & install the latest .dmg
  quit

Reads ~/Library/Application Support/Pomo/state.json; sends pomo:// URLs via open.`);
}

// ─── dispatch ────────────────────────────────────────────────────────────────

const rest = argv.slice(1);

switch (cmd) {
  // plain verbs
  case 'start':
  case 'pause':
  case 'toggle':
  case 'reset':
  case 'skip':
  case 'menu':
  case 'show':
  case 'hide':
  case 'logout':
  case 'settings':
  case 'stats':
  case 'quit':
    send(cmd);
    break;

  case 'login':
    await loginCmd(rest);
    break;

  case 'hud':
    send('hud');
    break;

  case 'session':
    if (!rest[0]) die('usage: pomo session <focus|short|long>');
    send(`session/${rest[0].toLowerCase()}`);
    break;

  case 'face':
    if (!rest[0]) die('usage: pomo face <name>');
    send(`face/${rest[0].toLowerCase()}`);
    break;

  case 'duration':
    if (!/^\d+$/.test(rest[0] || '')) die('usage: pomo duration <minutes>');
    send(`duration/${rest[0]}`);
    break;

  case 'intent':
    if (rest[0] === 'clear' || hasFlag(rest, 'clear') || rest.length === 0) {
      send('intent/clear');
    } else {
      send(`intent${query({ text: rest.join(' ') })}`);
    }
    break;

  case 'audio': {
    const a = rest[0] || '';
    if (a === 'session' || a === 'for') sessionAudio(rest.slice(1));
    else if (/^https?:\/\//i.test(a)) send(`audio${query({ url: a })}`);
    else if (['play', 'pause', 'stop', 'next', 'prev', 'previous'].includes(a.toLowerCase()))
      send(`audio/${a.toLowerCase()}`);
    else die('usage: pomo audio <url|play|pause|stop|next|prev|session>');
    break;
  }

  case 'volume':
    if (!/^\d+$/.test(rest[0] || '')) die('usage: pomo volume <0-100>');
    send(`volume/${rest[0]}`);
    break;

  case 'video': {
    const sub = (rest[0] || 'toggle').toLowerCase();
    if (!['show', 'hide', 'toggle', 'page', 'full', 'original', 'expand', 'player', 'bare', 'screen', 'collapse', 'browser', 'open'].includes(sub))
      die('usage: pomo video <show|hide|toggle|page|player|browser>');
    send(`video/${sub}`);
    break;
  }

  case 'fav':
  case 'favorite':
  case 'favorites':
    favorites(rest);
    break;

  case 'tui':
    runTui();
    break;

  case 'screenshot':
    writeScreenshot(rest);
    break;

  case 'status':
    printStatus(rest);
    break;

  case 'install':
    await install(rest);
    break;

  case '':
    // `pomo` alone → live TUI when we're in a terminal; one-shot status otherwise.
    if (existsSync(STATE_FILE)) runTui();
    else help();
    break;

  case 'help':
  case '--help':
  case '-h':
    help();
    break;

  default:
    die(`unknown command: ${cmd}\n      Run 'pomo help' for usage.`);
}
