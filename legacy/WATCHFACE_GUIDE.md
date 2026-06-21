# Watchface Creation Guide

This guide explains how to create custom watchfaces for the Pomo timer application.

## Watchface Structure

A watchface is defined as a JSON file with the following structure:

```json
{
  "id": "unique-identifier",
  "name": "Display Name",
  "description": "Brief description",
  "author": "Your Name",
  "version": "1.0.0",
  "theme": { /* Theme configuration */ },
  "layout": { /* Layout configuration */ },
  "components": [ /* Array of components */ ]
}
```

## Theme Configuration

The theme object defines colors, fonts, and custom styles:

```json
"theme": {
  "colors": {
    "background": "#ffffff",
    "foreground": "#000000",
    "accent": "#0066cc",
    "success": "#00cc00",
    "warning": "#ffcc00",
    "error": "#cc0000"
  },
  "fonts": {
    "primary": "system-ui, sans-serif",
    "accent": "monospace"
  },
  "customStyles": {
    // Custom CSS can be added here
    ".container": {
      "background": "linear-gradient(45deg, #000, #333)"
    }
  }
}
```

## Layout Configuration

The layout defines the overall structure:

```json
"layout": {
  "type": "circular" | "rectangular" | "custom",
  "size": {
    "width": 280,  // in pixels or "auto"
    "height": 280  // in pixels or "auto"
  },
  "padding": 20     // in pixels
}
```

## Components

Components are the building blocks of your watchface. Each component has:

- `id`: Unique identifier
- `type`: Component type
- `position`: Position on the watchface
- `style`: CSS styles
- `properties`: Component-specific properties

### Available Component Types

#### 1. Progress Ring (`progress`)
Shows a circular progress indicator.

```json
{
  "id": "main-progress",
  "type": "progress",
  "position": { "x": "center", "y": "center" },
  "style": {
    "radius": 100,
    "strokeWidth": 10,
    "strokeColor": "#0066cc",
    "backgroundColor": "#e0e0e0"
  }
}
```

#### 2. Time Display (`time`)
Shows the remaining time.

```json
{
  "id": "timer",
  "type": "time",
  "position": { "x": "center", "y": "center" },
  "style": {
    "fontSize": "48px",
    "fontWeight": "bold",
    "color": "#000000"
  }
}
```

#### 3. Status Display (`status`)
Shows the timer status (Running, Paused, etc.).

```json
{
  "id": "status",
  "type": "status",
  "position": { "x": "center", "y": 100 },
  "style": {
    "fontSize": "14px",
    "color": "#666666",
    "textTransform": "uppercase"
  }
}
```

#### 4. Control Buttons (`controls`)
Shows play/pause/stop buttons.

```json
{
  "id": "controls",
  "type": "controls",
  "position": { "x": "center", "y": 150 },
  "style": { "gap": "15px" },
  "properties": {
    "buttonStyle": {
      "background": "#0066cc",
      "color": "white",
      "borderRadius": "50%",
      "padding": "10px"
    }
  }
}
```

#### 5. Custom Components (`custom`)
For specialized visualizations.

Available custom components:
- `terminal-header`: Terminal-style header
- `ascii-progress`: ASCII progress bar
- `digital-display`: Digital clock display
- `retro-progress`: Retro segmented progress bar
- `minimal-progress`: Minimal line progress
- `neon-ring`: Neon glowing ring

```json
{
  "id": "custom-progress",
  "type": "custom",
  "position": { "x": "center", "y": 130 },
  "properties": {
    "component": "retro-progress",
    "style": {
      "width": "200px",
      "height": "10px",
      "background": "#333"
    }
  }
}
```

## Position System

Components can be positioned using:
- `"center"`: Centers the component
- Number: Absolute position in pixels
- Percentage: Relative to container size

## Complete Example

Here's a complete minimal watchface:

```json
{
  "id": "my-custom-face",
  "name": "My Custom Watchface",
  "description": "A simple custom watchface",
  "author": "Your Name",
  "version": "1.0.0",
  "theme": {
    "colors": {
      "background": "#1a1a1a",
      "foreground": "#ffffff",
      "accent": "#00ff00"
    },
    "fonts": {
      "primary": "Arial, sans-serif"
    }
  },
  "layout": {
    "type": "rectangular",
    "size": {
      "width": 300,
      "height": 200
    },
    "padding": 20
  },
  "components": [
    {
      "id": "time",
      "type": "time",
      "position": { "x": "center", "y": 60 },
      "style": {
        "fontSize": "48px",
        "color": "#ffffff"
      }
    },
    {
      "id": "status",
      "type": "status",
      "position": { "x": "center", "y": 110 },
      "style": {
        "fontSize": "12px",
        "color": "#00ff00"
      }
    },
    {
      "id": "controls",
      "type": "controls",
      "position": { "x": "center", "y": 150 },
      "style": { "gap": "10px" }
    }
  ]
}
```

## Loading Custom Watchfaces

1. Create your watchface JSON file
2. Open Pomo settings
3. Click "Load Custom Watch Face"
4. Select your JSON file
5. Your watchface will be added to the list and automatically selected

## Tips

1. Start with an existing watchface and modify it
2. Use the browser developer tools to inspect component rendering
3. Test your watchface with different timer states
4. Keep performance in mind - avoid too many complex components
5. Use web-safe fonts or Google Fonts via @import in customStyles

## Validation

Your watchface must include:
- Valid `id`, `name`, and `version` strings
- A `theme` object with at least `colors.background` and `colors.foreground`
- A `layout` object with a valid type
- At least one component in the `components` array

Invalid watchfaces will be rejected when loading.