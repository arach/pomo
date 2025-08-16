# @arach/dev-toolbar-react

A beautiful, minimal, and highly customizable development toolbar for React applications. Perfect for adding debug panels, state inspection, and development utilities to your projects.

## Features

- 🎨 Beautiful, minimal design
- 🌓 Dark/Light theme support
- 📍 Configurable positioning
- 🔧 Fully customizable tabs
- 🚀 Zero dependencies (except lucide-react for icons)
- 📦 Tiny bundle size
- 🎯 TypeScript support
- 🏭 Production-safe (auto-hides in production)

## Installation

```bash
npm install @arach/dev-toolbar-react
# or
pnpm add @arach/dev-toolbar-react
# or
yarn add @arach/dev-toolbar-react
```

## Quick Start

```tsx
import { DevToolbar } from '@arach/dev-toolbar-react';
import { Activity, Database, Settings } from 'lucide-react';

function App() {
  const tabs = [
    {
      id: 'state',
      label: 'State',
      icon: Database,
      content: (
        <div className="space-y-2 text-xs">
          <div>User: {user.name}</div>
          <div>Status: {status}</div>
        </div>
      )
    },
    {
      id: 'activity',
      label: 'Activity',
      icon: Activity,
      content: <ActivityMonitor />
    },
    {
      id: 'settings',
      label: 'Settings',
      icon: Settings,
      content: <SettingsPanel />
    }
  ];

  return (
    <>
      <YourApp />
      <DevToolbar tabs={tabs} />
    </>
  );
}
```

## Advanced Usage

### Custom Positioning

```tsx
<DevToolbar 
  tabs={tabs}
  position="top-left" // 'bottom-right' | 'bottom-left' | 'top-right' | 'top-left'
/>
```

### Custom Theme

```tsx
<DevToolbar 
  tabs={tabs}
  theme="light" // 'dark' | 'light' | 'auto'
/>
```

### Custom Icon and Title

```tsx
<DevToolbar 
  tabs={tabs}
  title="Debug"
  customIcon={<Wrench className="w-4 h-4" />}
/>
```

### Using Helper Components

```tsx
import { 
  DevToolbar, 
  DevToolbarSection,
  DevToolbarButton,
  DevToolbarInfo 
} from '@arach/dev-toolbar-react';

const tabs = [
  {
    id: 'debug',
    label: 'Debug',
    icon: Bug,
    content: (
      <DevToolbarSection title="State Info">
        <DevToolbarInfo label="Version" value="1.0.0" />
        <DevToolbarInfo label="Environment" value={process.env.NODE_ENV} />
        
        <div className="flex gap-1 mt-2">
          <DevToolbarButton 
            variant="success"
            onClick={() => console.log('Success!')}
          >
            Test Success
          </DevToolbarButton>
          
          <DevToolbarButton 
            variant="danger"
            onClick={() => console.error('Error!')}
          >
            Test Error
          </DevToolbarButton>
        </div>
      </DevToolbarSection>
    )
  }
];
```

### Dynamic Content

```tsx
const tabs = [
  {
    id: 'metrics',
    label: 'Metrics',
    icon: Activity,
    content: () => {
      // This function is called on each render
      const metrics = calculateMetrics();
      return (
        <div>
          <div>FPS: {metrics.fps}</div>
          <div>Memory: {metrics.memory}MB</div>
        </div>
      );
    }
  }
];
```

## Example: Timer/Pomodoro App Integration

```tsx
import { DevToolbar } from '@arach/dev-toolbar-react';
import { Timer, Play, Pause, RotateCcw } from 'lucide-react';

function PomodoroApp() {
  const { time, isRunning, start, pause, reset } = useTimer();
  
  const tabs = [
    {
      id: 'timer',
      label: 'Timer',
      icon: Timer,
      content: (
        <div className="space-y-2">
          <div className="text-sm font-mono">
            Time: {formatTime(time)}
          </div>
          <div className="text-xs text-gray-400">
            Status: {isRunning ? 'Running' : 'Paused'}
          </div>
          <div className="flex gap-1">
            <button onClick={start} className="p-1 bg-green-600 rounded">
              <Play className="w-3 h-3" />
            </button>
            <button onClick={pause} className="p-1 bg-yellow-600 rounded">
              <Pause className="w-3 h-3" />
            </button>
            <button onClick={reset} className="p-1 bg-red-600 rounded">
              <RotateCcw className="w-3 h-3" />
            </button>
          </div>
        </div>
      )
    }
  ];
  
  return (
    <>
      <TimerDisplay />
      <DevToolbar tabs={tabs} />
    </>
  );
}
```

## API Reference

### DevToolbar Props

| Prop | Type | Default | Description |
|------|------|---------|-------------|
| `tabs` | `DevToolbarTab[]` | Required | Array of tab configurations |
| `position` | `'bottom-right' \| 'bottom-left' \| 'top-right' \| 'top-left'` | `'bottom-right'` | Position of the toolbar |
| `defaultTab` | `string` | First tab | ID of the initially active tab |
| `theme` | `'dark' \| 'light' \| 'auto'` | `'auto'` | Color theme |
| `hideInProduction` | `boolean` | `true` | Auto-hide in production builds |
| `title` | `string` | `'Dev'` | Toolbar title |
| `customIcon` | `ReactNode` | `<Bug />` | Custom icon for the toggle button |
| `width` | `string` | `'280px'` | Width of the expanded toolbar |
| `maxHeight` | `string` | `'240px'` | Maximum height of the expanded toolbar |
| `className` | `string` | `''` | Additional CSS classes |

### DevToolbarTab Interface

```typescript
interface DevToolbarTab {
  id: string;
  label: string;
  icon: LucideIcon;
  content: ReactNode | (() => ReactNode);
}
```

## License

MIT

## Author

Created by [@arach](https://github.com/arach)

---

Built with ❤️ for developers who love beautiful tools.