# Watchface Versioning Guide

## Overview
This development setup allows side-by-side comparison of watchface versions to evaluate improvements during development.

## How It Works

### File Structure
```
src/components/watchface/watchfaces/
├── neon/
│   ├── NeonProgress.tsx      # Original (v1)
│   └── v2/
│       └── NeonProgressV2.tsx # Enhanced version
```

### URL Parameters
- `version=v1` or `version=v2` - Loads specific version
- `split=true` - Shows side-by-side comparison view
- `watchface=neon` - Specifies which watchface to load

### Development Commands

```bash
# Open split view comparison
pnpm dev:compare

# Compare Neon v1 and v2 in separate windows
pnpm dev:neon

# Open app with v2 versions
pnpm dev:v2
```

### Creating a v2 Version

1. Create a `v2` folder in the watchface directory
2. Copy the component and add "V2" to the name
3. Implement improvements in the v2 component
4. Register in WatchFaceRenderer's v2Components object

### Example URLs

- Split view: http://localhost:1421/?split=true
- Neon v1: http://localhost:1421/?watchface=neon&version=v1
- Neon v2: http://localhost:1421/?watchface=neon&version=v2

## Current v2 Implementations

### Neon v2
- Enhanced multi-layer glow effects
- Animated gradient colors
- Particle effects for atmosphere
- Active tick marks with glow
- Pulsing end cap animation
- Improved visual depth

## Future v2 Watchfaces
- Terminal v2: CRT effects, scanlines
- Rolodex v2: 3D card animations
- LCD v2: Authentic segment displays
- Default v2: Glass-morphism effects