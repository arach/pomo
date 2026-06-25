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
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { homedir, tmpdir } from 'node:os';
import { join } from 'node:path';
import { createInterface } from 'node:readline';
import { fileURLToPath } from 'node:url';

const REPO = 'arach/pomo';
const STATE_FILE = join(homedir(), 'Library', 'Application Support', 'Pomo', 'state.json');

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
function send(path) {
  requireMac();
  const url = `pomo://${path}`;
  const app = targetApp();
  try {
    execFileSync('open', app ? ['-a', app, url] : [url], { stdio: 'ignore' });
  } catch {
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
  status [--json]        show the live state (default when run with no command)
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

  case 'status':
    printStatus(rest);
    break;

  case 'install':
    await install(rest);
    break;

  case '':
    // bare `pomo` → a friendly status if the app's around, else help.
    if (existsSync(STATE_FILE)) printStatus([]);
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
