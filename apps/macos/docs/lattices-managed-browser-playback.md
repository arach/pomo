# Lattices Managed Browser Playback

Draft spec for using Lattices to control a real browser window for Pomo Amp
playback, without CDP, cookie import, or Google sign-in inside `WKWebView`.

Reviewed with the Lattices project through Scout: `ref:c-wu85gy`.

## Goal

Pomo Amp should offer a managed real-browser playback mode for users who want
their normal YouTube session, including Premium, playlists, queue, and browser
state. The browser remains a normal user browser window. Pomo Amp supplies the
small transport HUD and visual attachment; Lattices supplies desktop/window/UI
control.

This is not an ad blocker or ad-bypass system. Ad-free playback comes from the
user's own Premium session in their real browser.

## Product Shape

- Embedded WebKit remains the lightweight default player.
- Managed browser playback is an explicit source named `Browser`, not `Chrome`.
- The first implementation can target Google Chrome because that is the user's
  current logged-in Premium surface.
- The long-term contract should be browser-agnostic: `bundleId`, `appName`, and
  URL/window targeting should let Safari or another browser work later.
- Pomo Amp owns playback intent, menu bar UI, now-playing display, and whether
  the browser drawer is shown or hidden.
- Lattices owns locating, launching, moving, focusing, observing, and clicking
  real macOS windows.

## Non-Goals

- No embedded Google OAuth.
- No cookie copying as the main auth path.
- No CDP or remote debugging profile.
- No direct DOM scripting of YouTube.
- No hidden ad skipping or behavior whose purpose is to bypass ads.
- No global media-key control that could hit the wrong YouTube/browser window.

## Existing Lattices APIs We Can Use

### Health and Schema

- `daemon.status`: check that the local daemon is running.
- `api.schema`: discover current method shapes at runtime.

### Window Discovery

- `windows.list`: enumerate visible windows with `wid`, `app`, `pid`, `title`,
  `frame`, `spaceIds`, and `isOnScreen`.
- `windows.get`: refresh a tracked window by `wid`.
- `windows.search` or `lattices.search`: find a browser window by app/title/OCR.
- `windows.changed` event subscription: update Pomo if the browser window moves,
  closes, changes title, or is replaced. Today this event is useful as an
  invalidation signal, but it does not include detailed frame/title diffs.

Current window records do not include `bundleId`, so Pomo should treat `wid`,
`pid`, `app`, `title`, and user adoption as the initial identity anchors.

### Window Placement and Focus

- `computer.launchApp`: launch/focus a browser app by app name, bundle id, or
  explicit app path.
- `computer.focusWindow`: present or execute focus for a resolved window.
- `actions.execute` with `type=window.place`: preferred canonical placement
  surface when it can target a non-terminal window by `wid`.
- `window.place` / `window.focus`: compatibility surfaces where needed.
- `actions.undo`: useful for debug/recovery if a placement move goes wrong.

Reviewed status: `actions.execute(window.place)` already accepts
`target: { kind: "wid", wid }` and works for non-terminal windows, but current
placement shapes are tile/grid/fractions. Exact global frames and
`activation: none` need Lattices extensions.

### Observation

- `capture.screenshotWindow`: capture the browser window into a Lattices run.
- `ocr.scan`, `ocr.snapshot`, `ocr.search`: fallback text observation when AX
  names are insufficient.
- `runs.create`, `runs.get`, `runs.artifacts`: attach traces/screenshots to each
  browser-control attempt for debugging.

### UI Actions

- `computer.click`: click a window-relative target using `transport=auto`, `ax`,
  or `pointer`; supports `axLabel`, `noFocus`, `xRatio`, and `yRatio`.
- `computer.typeWindowText`: probably not needed for normal playback, but useful
  for search/login recovery flows if the user explicitly chooses them.
- `computer.magicCursor` / `computer.showCursor`: optional visible affordance for
  staged/debug mode.

## Lattices API Gaps / Requests

The existing API is close for window management and simple clicking. For Pomo Amp
to use this as a product-quality playback engine, we need a few stable contracts.

### 1. Generic URL Open and Window Resolve

The first draft proposed `browser.window.ensure`; Lattices review pushed back on
that shape as too browser/YouTube-specific. Keep YouTube URL normalization,
video id matching, and transport recipes in Pomo. If Lattices adds an API here,
it should be generic.

Needed API option A:

```json
{
  "method": "url.open",
  "params": {
    "appName": "Google Chrome",
    "bundleId": "com.google.Chrome",
    "url": "https://www.youtube.com/watch?v=...",
    "reusePolicy": "prefer-existing-window",
    "source": "pomo-amp"
  }
}
```

Needed API option B:

```json
{
  "method": "window.resolve",
  "params": {
    "target": {
      "kind": "app",
      "app": "Google Chrome",
      "titleContains": "YouTube"
    },
    "source": "pomo-amp"
  }
}
```

Why Pomo needs it:

- `computer.launchApp` can launch an app, but it does not define URL opening or
  reuse behavior.
- Pomo should not spawn a new browser window on every Show.
- Pomo needs to know whether the tracked window is still the same logical player.

Milestone 1 should avoid this problem entirely by adopting a user-selected
front browser window instead of opening URLs automatically.

### 2. Stable Non-Terminal Window Placement

Needed API:

```json
{
  "method": "actions.execute",
  "params": {
    "type": "window.place",
    "target": { "kind": "wid", "wid": 12345 },
    "args": {
      "placement": {
        "kind": "frame",
        "x": 1200,
        "y": 180,
        "w": 520,
        "h": 340,
        "coordinateSpace": "global"
      },
      "activation": "none"
    },
    "source": "pomo-amp"
  }
}
```

Requirements:

- Must work for Chrome/Safari, not only terminal sessions.
- Must return the applied frame, previous frame, display/space, and `undoable`.
- Must support `activation: none | present | focus`.
- Must be safe when the target is on another Space: either switch Space
  explicitly or return a recoverable error.

Reviewed status: `target.kind = "wid"` works today, but exact `frame` placement
and non-activating placement do not.

### 3. Park / Restore Without Minimize

Needed API:

```json
{
  "method": "window.park",
  "params": {
    "wid": 12345,
    "mode": "park|restore",
    "parkingFrame": { "x": 4000, "y": 200, "w": 520, "h": 340 },
    "source": "pomo-amp"
  }
}
```

Why:

- Minimize feels wrong and can break the mental model.
- Pomo wants Hide Video to tuck the browser away while preserving playback and
  the window identity.
- A parking-frame approach is acceptable if Lattices can make it reversible and
  robust across display changes.

Fallback:

- Pomo can call `window.place` to park/restore if Lattices confirms that
  offscreen frames are supported and safe.

Reviewed status: Lattices should not promise true hidden/order-out playback for
another app's browser window. Park/restore placement is the right model.

### 4. Keyboard / Shortcut Action

Needed API:

```json
{
  "method": "keyboard.send",
  "params": {
    "wid": 12345,
    "key": "space",
    "modifiers": [],
    "focusPolicy": "focus-required",
    "treatment": "execute",
    "source": "pomo-amp"
  }
}
```

Why:

- YouTube transport sometimes has better keyboard shortcuts than clickable AX
  controls.
- Pomo needs scoped keys so Space/Left/Right/Shift+N do not hit the wrong
  browser window.

Candidate mappings:

- Play/pause: `space` or click AX label `Play`/`Pause`.
- Next: click AX label `Next`, fallback `Shift+N` for playlist contexts.
- Previous: click AX label `Previous`, fallback `Shift+P` or visible button.
- Seek: `ArrowLeft` / `ArrowRight` only if the browser window is correctly
  targeted.

Reviewed status: a no-focus, window-scoped keyboard guarantee is not realistic
with normal macOS event delivery. Any keyboard fallback must focus and verify the
target window first. Milestone 1 should avoid keyboard fallback.

### 5. Accessibility Snapshot / Element Resolve

Needed API:

```json
{
  "method": "computer.inspectWindow",
  "params": {
    "wid": 12345,
    "includeScreenshot": true,
    "includeAX": true,
    "includeOCR": true,
    "source": "pomo-amp"
  }
}
```

Expected result:

```json
{
  "wid": 12345,
  "screenshotArtifact": "runs/.../window.png",
  "ax": [
    { "role": "button", "label": "Pause", "frame": { "...": "..." } }
  ],
  "ocr": [
    { "text": "Pause", "confidence": 0.93, "frame": { "...": "..." } }
  ]
}
```

Needed companion:

```json
{
  "method": "computer.resolveActionTarget",
  "params": {
    "wid": 12345,
    "role": "button",
    "labels": ["Pause", "Play"],
    "fallback": ["ocr", "ratio"],
    "source": "pomo-amp"
  }
}
```

Why:

- `computer.click` has `axLabel`, which is good for execution, but Pomo needs a
  way to preflight and explain what it thinks it will press.
- This lets the UI show "Browser controls ready" versus "Need user help".

Reviewed status: avoid stable AX ids; AX elements are ephemeral. A good first
step may be enhancing `computer.click` stage mode to return the chosen AX
candidate without pressing.

### 6. Permission Status

Needed API:

```json
{
  "method": "permissions.status",
  "params": {
    "capabilities": ["windowControl", "screenSearch", "voiceCapture"],
    "source": "pomo-amp"
  }
}
```

Needed companion:

```json
{
  "method": "permissions.openSettings",
  "params": { "capability": "accessibility", "source": "pomo-amp" }
}
```

Why:

- Pomo needs to render setup state before a user presses Browser mode.
- We should not ask blind or retry in a loop.
- If Lattices already owns permission education, Pomo should deep-link there
  rather than duplicate it.

Reviewed status: Lattices currently models `windowControl` as Accessibility,
`screenSearch` as Screen Recording, and `voiceCapture` as Microphone. It does
not currently model Input Monitoring through this capability layer.

### 7. Receipts and Run Traces

Every mutating browser-control call should eventually return:

- `requestId`
- `runId`
- target `wid` and app identity
- attempted transport (`ax`, `pointer`, `keyboard`, placement)
- before/after frame or screenshot artifact where relevant
- `ok`, `verification`, and a human-readable trace

This matters because failures will otherwise feel spooky: "play/pause just
switched windows" is exactly the class of bug receipts should explain.

Reviewed status: this is aspirational across surfaces today. Placement returns
action receipts; computer/capture calls return run objects and artifacts. Pomo
should tolerate that split.

## Pomo App Framework

### New Components

`LatticesClient`

- Swift JSON-RPC-over-WebSocket client to `ws://127.0.0.1:9399`.
- Calls `daemon.status` and `api.schema` on startup.
- Exposes typed async wrappers for the subset above.
- Does not shell out to `lattices` or depend on Node/Bun.

`ManagedBrowserPlaybackController`

- Owns the Lattices-backed playback state machine.
- Tracks `wid`, browser identity, current URL/video id, last visible frame,
  parked frame, and readiness.
- Converts Pomo actions into Lattices calls.

`BrowserPlaybackRecipe`

- Encodes browser-specific defaults for YouTube:
  - URL normalization
  - title/video matching
  - play/pause/next/previous action candidates
  - fallback coordinate ratios for the YouTube player chrome

`AudioController` integration

- Keep WebKit as default.
- Add explicit source only after this is proven: `.webkit` and `.browser`.
- Do not reintroduce CDP or cookie import as hidden source behavior.

### State Machine

- `unavailable`: Lattices daemon not reachable.
- `needsPermission`: Lattices is reachable but lacks required permissions.
- `idle`: no browser window tracked.
- `opening`: launching/finding/navigating browser.
- `ready`: tracked browser window is known and controls are resolvable.
- `visible`: tracked browser window is placed next to Pomo Amp.
- `hidden`: tracked browser window is parked/restorable.
- `recovering`: wid disappeared or control verification failed.
- `failed`: action failed with receipt; user can retry or open browser manually.

### Action Flow

Open/play URL:

1. Pomo normalizes URL and extracts YouTube video id.
2. Milestone 1: adopt an existing user-selected browser window.
3. Future: generic `url.open` or app open URL, then resolve/adopt the window.
4. Place window next to Amp HUD using Lattices placement.
5. Observe/snapshot controls.
6. Click Play or send scoped key only if the target is verified.
7. Store `wid`, frame, source URL, and receipt.

Play/pause:

1. If `ready`, prefer AX button label `Pause`/`Play` with `noFocus`.
2. If AX fails, resolve element from snapshot.
3. Milestone 1: if AX click is ambiguous, fail with a receipt and ask for
   user help.
4. Future: focus target and send scoped `space` only when `wid` is still the
   tracked browser window.
5. Save receipt and update Pomo state optimistically only after success.

Show/hide:

1. Show restores last visible frame and optionally activates Pomo Amp after.
2. Hide parks/restores without minimizing and without closing the browser.
3. If the user manually closes the browser window, Pomo transitions to `idle`.

Next/previous:

1. Prefer AX button labels.
2. Future: fall back to focused, verified keyboard shortcut.
3. Never send global media keys.

## UX

- Menubar source should say `Browser` only when enabled, never `Chrome`.
- Setup copy: "Use your real browser session for Premium playback."
- If Lattices is unavailable: "Browser control needs Lattices running."
- If permissions are missing: show a single setup action, not repeated prompts.
- Debug view can show the latest Lattices receipt/run id.

## Open Questions for Lattices

1. Should Pomo use existing `actions.execute/window.place` directly, with an
   extension for exact frames and activation policy?
2. Does `window.place` already support arbitrary `wid` targets and exact frames
   for non-terminal windows?
3. Should Lattices add generic `url.open`, or should Pomo launch URLs itself and
   only use Lattices for adoption/control?
4. What is the preferred no-minimize hide strategy: parking frame, Space move,
   ordered-out equivalent, or something else?
5. Is a focus-required keyboard action already available but undocumented?
6. Can `computer.click` return enough preflight detail for Pomo, or should we add
   `computer.inspectWindow` / `computer.resolveActionTarget`?
7. How should Pomo surface Lattices permission status without duplicating the
   Lattices settings UI?
8. Should the browser-control recipe live in Pomo, in Lattices, or as shared
   declarative data?

## First Milestone Proposal

Build a thin spike behind a debug flag:

- Add `LatticesClient` with `daemon.status`, `windows.list`, `computer.click`,
  `capture.screenshotWindow`, and `actions.execute`.
- Add a manual "Adopt Front Browser Window" debug action.
- Support only show/place with fractions placement and play/pause click by AX
  label.
- No automatic browser launching yet.
- No offscreen hide/park yet.
- No keyboard fallback yet.
- Use Lattices run receipts for every action.

Success criteria:

- No extra browser windows after repeated show/hide.
- Play/pause targets the adopted YouTube window, not another YouTube tab/window.
- Hide/show does not minimize and does not reload.
- Failures produce a receipt with target, transport, and reason.
