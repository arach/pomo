# Pomo Landing Page

This is the landing page for Pomo, a minimalist Pomodoro timer for macOS.

## Getting Started

First, install dependencies:

```bash
pnpm install
# or
npm install
```

Then, run the development server:

```bash
pnpm dev
# or
npm run dev
```

Open [http://localhost:4321](http://localhost:4321) to see the landing page.

> **Note**: The landing page runs on port **4321** to avoid conflicts with other local development servers.

## Building for Production

To create a production build:

```bash
pnpm build
# or
npm run build
```

The static output will be in the `out` directory, ready to be deployed to any static hosting service.

## Features

- **SEO Optimized**: Full meta tags, Open Graph, and Twitter cards
- **Responsive Design**: Works beautifully on all devices
- **Dark Theme**: Matches the app's aesthetic
- **Interactive Demo**: Live timer preview
- **Performance**: Static export for fast loading

## Deployment

This site can be deployed to any static hosting service:

- Vercel
- Netlify
- GitHub Pages
- Cloudflare Pages

Simply point to the `out` directory after building.