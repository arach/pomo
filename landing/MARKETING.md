# Pomo marketing kit

The landing-page campaign uses the shipping iPhone interface directly—no
generic device renders and no generated product UI.

## Campaign set 01–05

| Asset | Message | Source |
| --- | --- | --- |
| 01 · Timer | Set an intention. | `public/marketing/iphone-timer-v2.png` |
| 02 · Faces | Choose your face. | `public/marketing/iphone-faces-v2.png` |
| 03 · Focus view | Just the timer. | `public/marketing/iphone-immersive-v2.png` |
| 04 · Session length | Set the time. | `public/marketing/iphone-duration-v2.png` |
| 05 · Activity | See your rhythm. | `public/marketing/iphone-activity-v2.png` |

All five product screenshots are 1320 × 2868 iPhone 16 Pro Max captures.

## App Store promotional set

The upload-ready 6.9-inch product-page images live in
`../apps/ios/AppStore/PromotionalV2/`:

| File | Copy |
| --- | --- |
| `01-hero.png` | Pick a face. Begin. |
| `02-timer.png` | Set an intention. |
| `03-faces.png` | Choose your face. |
| `04-immersive.png` | Just the timer. |
| `05-duration.png` | Set the time. |
| `06-activity.png` | See your rhythm. |

Each image is 1320 × 2868. The reusable renderer lives in
`components/app-store-promo.tsx`; its export routes are
`/app-store/hero`, `/app-store/timer`, `/app-store/faces`, `/app-store/immersive`,
`/app-store/duration`, and `/app-store/activity`.

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
