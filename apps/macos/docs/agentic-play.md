# Agentic play capability

Draft spec for a deterministic, verifiable **agentic play** capability: an
authorized agent opens the *intended* Pomo app, plays an *explicit* media URL,
and gets back proof that playback actually began — without surprising the human
who owns the machine.

- Task id: `agentic-play`
- Requested by: `talkie.master` via Scout ask `q2ymwd`
- Status: **step 1 (observability) implemented and verified; steps 2–6 not started**
- Companion spec: [lattices-managed-browser-playback.md](lattices-managed-browser-playback.md)
  (real-browser playback). This spec covers the *embedded WebKit* path, which is
  and stays the default engine.

## Goal

Make "play this URL in Pomo" a first-class agent operation with a definite
outcome. Today an agent can *fire* playback but cannot *confirm* it, cannot tell
*which* Pomo instance obeyed, and cannot avoid hijacking a human's focus session
or blasting audio at an unknown volume.

Success is a single call that returns one of a closed set of outcomes —
`playing`, `unauthorized`, `auth_required`, `unplayable`, `ambiguous_target`,
`refused_busy`, `timeout` — each with a receipt.

The target may be Pomo or Pomo Amp. The caller names the intended bundle id or
canonical app path; the capability never silently forwards between them.

## Non-Goals

- No new playback engine. This is a control/observability contract over the
  existing `WebAudioPlayer` + `pomo://` surface.
- No ad blocking or ad bypass.
- No implicit takeover of a running focus session (see Safety).
- No new auth path. Sign-in stays `pomo login` / `pomo login import`.
- No agent-initiated *content discovery*. The URL is always supplied explicitly
  by the caller; Pomo never picks media on an agent's behalf.

## What Already Exists

Command surface — `apps/macos/Sources/PomoShared/Control/AgentControl.swift`:

- `pomo://audio?url=<url>` → `.audioPlay(url)` (`AgentControl.swift:146`)
- `pomo://audio/play|pause|stop|next|prev`, `pomo://volume/<0-100>`
- `pomo://favorite/play/<n>`, `pomo://audio/session/<type>?url=`
- `pomo://video/show|hide|toggle|page|player|browser`

URL normalization and playability — `Audio/PlaybackSource.swift`:

- `PlaybackSource.detect` / `isPlayable` / `playbackURL(from:pageMode:)`
- `youTubeID(from:)` — canonical id extraction, already agent-grade

Delivery — `apps/cli/bin/pomo.js`:

- `send()` (`pomo.js:64`) shells `open` with the `pomo://` URL
- `targetApp()` (`pomo.js:57`) honours `POMO_APP`, else prefers the repo-sibling
  `apps/macos/dist/Pomo.app`, else returns `null` → default LaunchServices routing

Read-back — `PomoState` (`AgentControl.swift:239`), written by
`AppDelegate.writeState()` (`AppDelegate.swift:381`) to
`~/Library/Application Support/Pomo/state.json`. Relevant fields today:
`audioPlaying: Bool`, `audioURL: String`, `audioEngine: "web" | "none"`.

In-player telemetry that exists but never leaves the WebView — the injected JS in
`PlaybackSource.playerAttachmentJS` already posts `playing`, `playfail:<err>`,
`no-video`, `state:0|1|2`, and
`clock:{time,duration,paused,rate,ended}` back over the `pomo` message handler.

## Gaps That Block Determinism

### G1 — `state.json` has no writer identity

`PomoState.fileURL` (`AgentControl.swift:261`) resolves to one shared path,
`~/Library/Application Support/Pomo/state.json`, for **every** bundle id that
ships: `dev.pomo.hud.dev` (dev build), `dev.pomo.hud` (release), the legacy
`com.pomo.dev` / `dev.pomo.hud.spreview` ids, and Pomo Amp
(`dev.pomo.amp.dev` / `dev.pomo.amp`, see `AppDelegate.swift:365`). Last writer
wins. An agent reading the file **cannot know which app it just observed**, so
"playback began" is unattributable whenever more than one instance is alive.

### G2 — No freshness stamp

There is no `updatedAt`. A `state.json` left behind by an app that has since
quit is indistinguishable from a live one, so `audioPlaying: true` can be a
ghost. Every verification loop built on this file is silently unsound.

### G3 — `audioPlaying` is a boolean, so "began" is unprovable

A boolean cannot distinguish *playing* from *buffering forever* or *paused at
0:00 with the play flag latched*. Proof of playback requires a **monotonically
advancing position**. The data already exists (`clock:` messages) and is thrown
away before it reaches `state.json`.

### G4 — Commands are fire-and-forget and uncorrelated

`open pomo://audio?url=…` returns as soon as `open` succeeds — that only proves
LaunchServices accepted a URL, not that Pomo parsed it, liked it, or acted.
`PomoCommand.init?` returns `nil` for malformed input and the failure is
invisible to the caller. With no request id, a retry or a second agent cannot
tell whose play won.

### G5 — Target app resolution is ambiguous by design

`targetApp()` returns `null` for a plain npm install, so bare `open pomo://…`
routes to "whatever LaunchServices picks" — the function's own header comment
documents this hazard for stale worktrees, mounted DMGs, and cached builds. When
the dev build *and* `/Applications/Pomo.app` are both running, commands land on
the wrong instance and two HUDs appear.

### G6 — Signed-in state is per-bundle-id

Each bundle id gets its own WebKit cookie jar at `~/Library/WebKit/<bundleid>/`,
so a YouTube login does **not** carry across dev and release. The same URL can
play in one instance and fail sign-in in another. Age-gated, private, or
members-only media surfaces as `playfail:` with no distinct outcome, so an agent
cannot tell "needs login" from "broken link" and will retry pointlessly.

### G7 — Verification is audible

Confirming playback means making real sound on a real human's speakers. Two
concrete hazards, both live on this machine right now: a focus session in
progress (`phase: "running"`) already playing a track, and an unknown system
volume. An agent that verifies naively interrupts the session and may be loud.

### G9 — The obvious position signal is extrapolated, not observed

`WebAudioPlayer.estimatedMediaTime(at:)` (`WebAudioPlayer.swift:315`) adds
`hostTime - mediaClockHostTime` whenever `isPlaying && !mediaPaused`. It therefore
keeps climbing for a page that has loaded and gone silent, which would make a
stalled load look like healthy playback. Proof must use the position **as last
reported by the player**, paired with when that report arrived.

Found while implementing step 1; the fix is in place (see Implementation Status).

### G10 — Live streams have no advancing position

A YouTube live stream reports `duration: Infinity` (written as `0`) and a
`currentTime` pinned near `0`. Measured on `youtu.be/jfKfPfyJRdk` — favorite #1 in
this user's own list — position stayed `0.000` across nine samples while the
stream played normally. Position-advance alone would therefore classify a healthy
livestream as `timeout`.

Live media needs a different liveness signal: `audioPlayerPaused == false` with
`audioPositionReportedAt` advancing proves the player is alive and reporting.
Acceptance criterion 10 must carve this out, or it will fail correct behaviour.

### G8 — A bundle id is not an installation identity

`/Applications/Pomo.app`, a mounted release DMG, and copied or cached builds can
share the same bundle id. A state file keyed only by bundle id, or
`open -b <bundleId>`, still cannot prove which bundle path or process handled a
command. Duplicate handling therefore needs a launch-scoped identity and a
direct per-instance command route; bundle id alone is insufficient.

## Proposed Contract

### 0. Authorization boundary

The verified agentic path is opt-in and deny-by-default. Pomo must accept it
only from a locally authorized caller (for example, an enabled Agent Control
setting plus a locally issued, scoped capability supplied out of band). The
implementation may choose the concrete transport, but it must:

- scope authorization to the exact target bundle and the `audio/open` action;
- keep capability material out of command-line arguments, `pomo://` URLs,
  receipts, logs, and state files;
- return `unauthorized` before launching an app, loading a URL, changing
  playback, or producing sound; and
- allow authorization to be revoked without changing the human-oriented legacy
  `pomo://audio?url=` behavior.

### 1. Command: `pomo://audio/open`

```
pomo://audio/open
  ?url=<explicit media url>          # required, no default, no discovery
  &requestId=<caller-chosen id>      # required for verifiable play
  &volume=<0-100>                    # optional cap applied before first frame
  &takeover=<none|pause|replace>     # default none (see Safety)
  &probe=<1>                         # optional: resolve + validate, no sound
  &timeoutMs=<n>                     # default 10000
```

`probe=1` runs everything except audio: normalize the URL via
`PlaybackSource.playbackURL`, confirm `isPlayable`, report resolved id, engine,
account status, and whether a takeover decision would be required. This is the
safe dry run an agent should call first.

Keep `pomo://audio?url=` working unchanged for humans and existing scripts.

### 2. Extend `PomoState` with identity, freshness, and progress

```swift
struct PomoStateWriter: Codable {
    var bundleId: String      // dev.pomo.hud.dev | dev.pomo.hud | dev.pomo.amp…
    var bundlePath: String    // canonical path of the running .app
    var appName: String       // "Pomo" | "Pomo Dev" | "Pomo Amp"
    var pid: Int32
    var launchId: String      // random UUID, unique for this process lifetime
    var version: String
}

struct PomoCommandReceipt: Codable {
    var requestId: String
    var verb: String          // "audio/open"
    var acceptedAt: String    // ISO8601
    var resolvedURL: String   // post-normalization, what actually loaded
    var outcome: String       // playing | unauthorized | auth_required |
                              // unplayable | refused_busy | timeout | probe_ok
    var detail: String        // e.g. underlying playfail: text
}

// added to PomoState
var writer: PomoStateWriter
var updatedAt: String         // ISO8601, every write
var seq: Int                  // monotonic per process, survives equal timestamps
var audioPositionSeconds: Double
var audioDurationSeconds: Double
var audioTitle: String
var audioAccountStatus: String   // signedOut | signedIn | unknown
var lastCommand: PomoCommandReceipt?
```

Bridge the existing `clock:` / `playing` / `playfail:` / `no-video` messages into
these fields instead of dropping them.

Correction to an earlier assumption in this spec: `writeState()` does **not** run
on a tick. It is purely event-driven (`AppDelegate.swift:120` and neighbours), and
`handleMediaClock` did not notify, so an advancing track left a frozen position on
disk whenever the timer was idle. Progress therefore needs its own throttled
notification — see Implementation Status.

Additive and optional-tolerant: `pomo status --json`, the TUI, and any agent
reading the old three audio fields keep working.

### 3. Launch-scoped state, with the shared file kept as a convenience

Write
`~/Library/Application Support/Pomo/instances/<launchId>/state.json` for each
running process and maintain an atomic instance registry containing `launchId`,
canonical `bundlePath`, bundle id, pid, and freshness. Remove the registry entry
on clean exit; readers also reject dead pids or stale timestamps.

Keep the existing `state.json` as a last-writer-wins compatibility file, now
carrying `writer` so a reader can tell what it got. Do not use
`state-<bundleId>.json` as the deterministic key: two copies with the same
bundle id would collide.

### 4. Deterministic target selection

Add `pomo apps --json`: enumerate installed *and* running Pomo bundles with
bundle id, canonical path, version, pid, launch id, and which one `targetApp()`
would choose. Make target selection explicit and failure-loud:

- `POMO_APP` or `--app <path>` → use exactly that canonical bundle path
- `--app <bundleId>` → use it only when exactly one canonical path matches
- repo-sibling `dist/Pomo.app` → dev, as today
- exactly one installed bundle → use it
- more than one candidate and no explicit choice → **fail** `ambiguous_target`
  and list the candidates; never guess

For a stopped target, launch that exact path and wait for a fresh registry entry
whose `writer.bundlePath` matches it. If the exact path is already running, use
its current `launchId`. If two processes for the same path exist, require an
explicit `--launch-id`.

The verified command must then go to a launch-scoped local endpoint (for
example, a user-only Unix socket or equivalent IPC advertised in that launch's
registry entry). It must not use bare LaunchServices URL routing, because
`pomo://` cannot distinguish two processes with the same bundle id. Keep the
existing URL scheme for backward compatibility, not as proof-bearing delivery.

This turns G5 and G8 from silent misroutes into caller-visible decisions.

### 5. Verify loop

`pomo play <url> --verify` (and the equivalent for a direct agent):

1. `pomo apps --json` → resolve exactly one target, else `ambiguous_target`.
2. Launch the exact canonical app path if needed, then wait for the matching
   fresh `launchId` and direct command endpoint. A mismatch is a hard failure.
3. Read that launch's state → capture `seq`, `phase`, `audioPlaying`, and
   `audioAccountStatus`; apply the Safety gate below.
4. Send `audio/open` with a fresh `requestId` and, unless told otherwise, a
   volume cap.
5. Poll the launch-scoped state file until `lastCommand.requestId` matches — this
   proves *the intended app parsed the command*, closing G4.
6. Require, within `timeoutMs`: `audioPlaying == true`, `audioURL` equal to the
   resolved URL, and `audioPositionSeconds` **strictly greater** at two samples
   ≥1s apart with `updatedAt` advancing. Position movement — not the boolean —
   is the proof (G3).
7. Return the receipt. On failure return the receipt's outcome, never a bare
   false.

### 6. Safety gate (audible side effects, G7)

Before any sound, read the target's live state and refuse-by-default when
playback would disturb the human:

| Preflight state | `takeover=none` (default) | `pause` | `replace` |
| --- | --- | --- | --- |
| `phase == running` and `audioPlaying` | `refused_busy` | pause current, play new | replace current |
| `phase == running`, silent | play at capped volume | — | — |
| idle / paused | play at capped volume | — | — |

Additional rules:

- Volume: if `volume` is omitted, clamp the first play to the lower of the
  stored volume and a spec'd verification ceiling; never raise system volume.
- `probe=1` is always allowed and always silent.
- Every audible action lands in `lastCommand`, so there is a record of what made
  noise and which agent asked.

### 7. Signed-in sessions (G6)

`audioAccountStatus` comes from the existing `AccountStatus` / `AuthService`
surface. Map an auth-shaped `playfail:` to the distinct `auth_required` outcome
with the target's bundle id in `detail`, so the agent can say "this instance is
signed out — run `pomo login import --app <id>`" instead of retrying. An agent
must never attempt sign-in itself; `auth_required` is a terminal handoff to the
human.

## Acceptance Criteria

Numbered so review can accept or cut them individually.

**Authorization**

A1. With Agent Control disabled, or with absent/invalid authorization, verified
play returns `unauthorized` and does not launch an app, load the URL, mutate
state, or produce sound.
A2. Authorization for one canonical target/launch or action cannot be replayed
against another target, launch, or broader command, and no capability secret
appears in process arguments, URLs, receipts, logs, or state files.

**Identity and freshness**

1. `state.json` and each launch-scoped state file carry `writer.bundleId`,
   `writer.bundlePath`, `writer.appName`, `writer.pid`, `writer.launchId`,
   `writer.version`, `updatedAt`, and a monotonic `seq`.
2. With the dev build and the release running simultaneously, an agent can read
   the state of a *named* instance and never be served the other's.
3. Two running copies with the same bundle id but different paths have distinct
   launch ids, registry entries, command endpoints, and state files. A dead pid
   or stale timestamp makes an entry rejectable without guessing.

**Deterministic targeting**

4. `pomo apps --json` lists every installed and running Pomo/Pomo Amp bundle with
   id, canonical path, version, pid, launch id, and the would-be default target.
5. With two or more candidate bundles and no `POMO_APP`/`--app`, a verified play
   exits non-zero with `ambiguous_target` and the candidate list. It does not
   pick one.
6. With `--app <path>`, a stopped target is launched from that exact canonical
   path and the command provably reaches its launch id — asserted via
   `lastCommand.requestId` appearing in that launch's state file and nowhere
   else. Bare `pomo://` routing is not used for this proof.

**Verifiable playback**

7. `audioPositionSeconds`, `audioDurationSeconds`, and `audioTitle` are populated
   from the existing in-player `clock:` telemetry within 2s of playback starting.
8. A verified play of a known-good public URL returns `playing` with a receipt
   containing `requestId`, `resolvedURL`, and both position samples.
9. `resolvedURL` equals `PlaybackSource.playbackURL(from:pageMode:false)` for the
   input, and a `youtu.be/<id>` input verifies against its normalized
   `watch?v=<id>` form rather than reporting a mismatch.
10. A URL that loads but never advances position yields `timeout`, not
    `playing` — verified by a deliberately stalled or non-media URL. **Live media
    is exempt** (G10): a stream reporting `duration == 0` is proven live by
    `audioPlayerPaused == false` plus advancing `audioPositionReportedAt`, and must
    not be failed for a pinned position.
11. A malformed or unplayable URL yields `unplayable` **from the app**, not a
    silent no-op. `PomoCommand.init?` returning `nil` must still produce a
    receipt.
12. Re-issuing the same `requestId` is idempotent: no second load, and the
    original receipt is returned.

**Safety**

13. Default `takeover=none` against a running focus session with audio playing
    returns `refused_busy` and **produces no sound**. Asserted by
    `audioURL`/`audioPositionSeconds` continuity across the attempt.
14. `probe=1` returns `probe_ok` with resolved URL, engine, and account status,
    and produces no sound in any preflight state.
15. A play with `volume=N` never exceeds `N`, and no code path raises system
    output volume.
16. `takeover=pause` and `takeover=replace` each do exactly what they say, and
    are the *only* ways an agent interrupts existing audio.

**Auth**

17. A signed-out instance asked for auth-requiring media returns `auth_required`
    naming the bundle id, distinct from `unplayable`, with no retry loop.
18. Signing in on one bundle id does not change the reported
    `audioAccountStatus` of another — documenting G6 rather than papering over it.

**Compatibility**

19. `pomo://audio?url=` and `pomo audio <url>` behave exactly as they do today.
20. A consumer reading only the pre-existing `audioPlaying` / `audioURL` /
    `audioEngine` fields is unaffected.

## Open Questions

1. Verification volume ceiling: fixed default, a setting, or must every agentic
   play state `volume` explicitly?
2. Should `refused_busy` be softened when the caller *is* the agent that started
   the current track (same-agent takeover), or stay uniformly strict?
3. How long should stale launch directories and registry entries be retained
   for diagnostics before cleanup?
4. Is `lastCommand` (single slot) enough, or does concurrent multi-agent use need
   a short receipt ring buffer?
5. Should `probe=1` be allowed to prefetch metadata (title/duration) over the
   network, or must a silent probe also be network-silent?

## Implementation Status

### Step 1 — Observability: done, verified live

Shipped fields on `PomoState` (`Control/AgentControl.swift`):

- `writer` — `bundleId`, `bundlePath` (canonical), `appName`, `pid`, `launchId`
  (fresh UUID per process), `version`. Resolved once via `PomoStateWriter.current`,
  so `launchId` *is* the launch identity.
- `updatedAt` — UTC ISO8601 **with** the `Z` designator, and `seq`, a per-process
  monotonic counter. Both are stamped inside `write()` rather than by callers, so a
  snapshot cannot claim to be fresh without being fresh. `seq` restarts per launch
  and is only meaningful scoped to a `launchId`.
- `audioPositionSeconds` + `audioPositionReportedAt` — the position **as reported by
  the player** and when that report arrived, not `estimatedMediaTime(at:)` (G9).
- `audioPlayerPaused` — the player's own paused flag, the live-safe signal for G10.
- `audioDurationSeconds`, `audioTitle`, `audioAccountStatus`.

`audioAccountStatus` is three-state on purpose: `AccountStatus.signedIn` starts
`false` and is only populated after a page load, so before any load it reports
`unknown` rather than an untrue `signedOut`.

Progress plumbing: `WebAudioPlayer.onPlaybackClock` → `AudioController.
onPlaybackProgress` → `AppDelegate.writeState()`, throttled to 1s (matching the
verify loop's "two samples ≥1s apart"). Deliberately *not* routed through
`onStateChange`, which republishes `@Observable` properties and would invalidate
the HUD and popover once a second for the entire duration of playback.

Verified against the running dev build (`dev.pomo.hud.dev`):

- Finite video (`youtu.be/PsHOAjqFIok`): position advanced 0.693 → 4.731 with
  `duration` 7200.2, title populated, `audioPositionReportedAt` and `seq` advancing
  ~1/s. **Criterion 7 met.**
- Live stream (`youtu.be/jfKfPfyJRdk`): position pinned at 0.000 and duration 0,
  while `audioPlayerPaused == false` and `audioPositionReportedAt` advanced ~1/s —
  the G10 case and its signal, both reproduced.
- `writer` correctly reported `dev.pomo.hud.dev`, the canonical `dist/Pomo.app`
  path, pid, and a new `launchId` on each relaunch. **Criterion 1 met** for the
  shared file; criteria 2–3 still need step 2's launch-scoped files.
- Compatibility: `pomo status` and `pomo status --json` unchanged, legacy
  `audioPlaying`/`audioURL`/`audioEngine` intact. **Criteria 19–20 hold.**

G2 was also confirmed by accident: with no Pomo process running at all, the old
`state.json` still read `phase: "running"` with audio playing. Stale state really
does masquerade as live, which is what `updatedAt`/`pid`/`launchId` now fix.

Not in step 1, still open: `lastCommand` receipts (step 3), launch-scoped state and
the direct command endpoint (step 2), and the authorization boundary (section 0) —
until that lands, none of this is a *verified authorized* path, only better
observability on the existing human-facing one.

## Suggested Implementation Order

Each step is independently shippable and testable.

1. ~~**Observability first**~~ — **done**, see Implementation Status. Criteria 1, 7,
   19, 20 met; 3 partly (stale detection works, per-launch isolation needs step 2).
2. **Launch registry, launch-scoped state, and direct local command endpoint** +
   `pomo apps --json` (criteria 2–6).
3. **`requestId` + `lastCommand` receipts** on the existing `audio` verbs
   (criteria 6, 8, 11, 12).
4. **`audio/open` with `probe`, `volume`, `takeover`** and the safety gate
   (criteria 13–16).
5. **Explicit target resolution / `ambiguous_target`** in the CLI (criterion 5).
6. **`auth_required` mapping** from `AccountStatus` (criteria 17, 18).
