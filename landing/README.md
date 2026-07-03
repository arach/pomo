# Pomo Landing Page

Marketing site for Pomo at **[pomo.arach.dev](https://pomo.arach.dev)**.

## Getting Started

```bash
bun install
bun run dev
```

Open [http://localhost:3000](http://localhost:3000) to preview locally.

## Building for Production

```bash
bun run build
```

Static output lands in `out/`, including `CNAME` for the custom domain.

## Deployment

Pushes to `main` that touch `landing/**` trigger
[`.github/workflows/deploy-landing.yml`](../.github/workflows/deploy-landing.yml),
which builds with bun and deploys to GitHub Pages.