# Pomo marketing kit

The landing-page campaign uses the shipping iPhone interface directly—no
generic device renders and no generated product UI.

## Campaign set 01–04

| Asset | Message | Source |
| --- | --- | --- |
| 01 · Focus | Focus on the task. | `public/marketing/iphone-focus.png` |
| 02 · Faces | Choose a timer face. | `public/marketing/iphone-blueprint.png` |
| 03 · Activity | Review your activity. | `public/marketing/iphone-activity.png` |
| 04 · Settings | Adjust the timer. | `public/marketing/iphone-settings.png` |

All four product screenshots are 1320 × 2868 iPhone 16 Pro Max captures.

## App Store promotional set

The upload-ready 6.9-inch product-page images live in
`../apps/ios/AppStore/Promotional/`:

| File | Copy |
| --- | --- |
| `01-focus.png` | Focus on the task. |
| `02-faces.png` | Choose a timer face. |
| `03-activity.png` | Review your activity. |
| `04-settings.png` | Adjust the timer. |

Each image is 1320 × 2868. The reusable renderer lives in
`components/app-store-promo.tsx`; its export routes are
`/app-store/focus`, `/app-store/faces`, `/app-store/activity`, and
`/app-store/settings`.

## Social / Open Graph

- `public/marketing/pomo-iphone-campaign-1200x630.png`
- `public/og-image.png` (the deployed metadata target)

Both are 1200 × 630 and use the same real screenshot deck as the landing page.

## Segment glyph family

The Build, Write, Study, and Design glyphs are custom inline SVGs in
`app/home-content.tsx`. They share a 64-unit schematic frame, 1.6-unit rounded
strokes, a signal-yellow datum, and a subtle Blueprint-blue construction grid.
They are intentionally code-native so they remain sharp, themeable, and easy to
reuse in responsive layouts.

## Campaign palette

- Charcoal: `#17120f`
- Elevated surface: `#211a15`
- Warm white: `#f4eee6`
- Muted copy: `#a89b8b`
- Signal yellow: `#eae434`
- Blueprint blue: `#70b7ff`
- Drafting orange: `#f2a65a`
