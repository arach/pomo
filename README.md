# Pomo - Minimal Floating Pomodoro Timer

A simple, floating Pomodoro timer application designed to overlay on your desktop with minimal UI and maximum functionality. Built with Tauri, React, and TypeScript.

<div align="center">
  <img src="./screenshots/expanded-view.png" alt="Pomo Timer - Expanded View" width="320" />
  <img src="./screenshots/collapsed-view.png" alt="Pomo Timer - Collapsed View" width="320" />
</div>

<p align="center">
  <em>Beautiful, minimal design that stays out of your way while keeping you productive</em>
</p>

## Why Pomo? 🍅

Stop letting timers interrupt your flow. Pomo floats elegantly above your work, collapsing to a tiny bar when you need space, expanding when you need control. It's the Pomodoro timer that finally respects your workspace.

- **Stays out of your way** - Collapse to a minimal 25:00 display with one middle-click
- **Always accessible** - Hyperkey+P brings it back instantly, no dock diving needed
- **Beautifully minimal** - Gradient progress rings and smooth animations make time tracking a pleasure
- **Your timer, your rules** - Set any duration, pick your sound, customize your shortcut

## Features

- 🪟 **Floating Window** - Always-on-top transparent window that floats above other applications
- ⌨️ **Customizable Shortcuts** - Set your own keyboard shortcut for toggle visibility
- ⏱️ **Custom Timer** - Set any duration with MM:SS format or use quick presets
- 🎯 **Minimal UI** - Clean, distraction-free interface with visual countdown
- 🔄 **Collapsible Design** - Middle-click the title bar to collapse/expand
- 🔊 **Sound Library** - Choose from multiple notification sounds with volume control
- ⚙️ **Advanced Settings** - Customize opacity, sounds, shortcuts, and window behavior
- 🎨 **Modern Design** - Beautiful dark theme with gradients, animations, and glass effects

## Quick Start 🚀

```bash
# Clone and enter
git clone git@github.com:arach/pomo.git && cd pomo

# Install and run
pnpm install && pnpm tauri:dev

# That's it! Press Hyperkey+P to toggle visibility
```

## Getting Started

### Prerequisites

- [Node.js](https://nodejs.org/) (v16 or higher)
- [pnpm](https://pnpm.io/) (recommended) or npm
- [Rust](https://www.rust-lang.org/) (latest stable)
- [Tauri Prerequisites](https://tauri.app/v1/guides/getting-started/prerequisites)

### Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:arach/pomo.git
   cd pomo
   ```

2. Install dependencies:
   ```bash
   pnpm install
   ```

3. Run in development mode:
   ```bash
   pnpm tauri:dev
   ```

### Building for Production

```bash
pnpm tauri:build
```

The built application will be in `src-tauri/target/release/bundle/`.

## Usage

### Timer Controls
- **Start/Pause** - Click the play/pause button
- **Stop** - Click the stop button to reset the timer
- **Set Duration** - Enter minutes and seconds in the input fields
- **Quick Presets** - Click 5m, 15m, 25m, or 45m buttons

### Keyboard Shortcuts
- **Hyperkey+P** - Toggle window visibility (Cmd+Ctrl+Alt+Shift+P on macOS)

### Window Controls
- **Drag** - Click and drag the title bar to move the window
- **Collapse/Expand** - Middle-click the title bar
- **Close** - Click the red traffic light button
- **Minimize** - Click the yellow traffic light button

## Development

### Project Structure
```
pomo/
├── src/                    # React frontend
│   ├── components/         # UI components
│   ├── stores/            # Zustand state management
│   └── App.tsx            # Main app component
├── src-tauri/             # Rust backend
│   ├── src/
│   │   ├── lib.rs         # Core timer logic
│   │   └── main.rs        # Entry point
│   └── tauri.conf.json    # Tauri configuration
└── package.json           # Frontend dependencies
```

### Key Technologies
- **[Tauri 2.0](https://tauri.app/)** - Desktop app framework
- **[React](https://react.dev/)** - UI library
- **[TypeScript](https://www.typescriptlang.org/)** - Type safety
- **[Tailwind CSS](https://tailwindcss.com/)** - Styling
- **[Zustand](https://zustand-demo.pmnd.rs/)** - State management

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow the existing code style
- Write clear commit messages
- Update documentation as needed
- Test on multiple platforms if possible

## Roadmap

- [ ] Custom notification sounds
- [ ] Multiple timer presets
- [ ] Session statistics
- [ ] Theme customization
- [ ] Break timer integration
- [ ] Productivity analytics

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by the need for a simple, unobtrusive Pomodoro timer
- Built with the excellent [Tauri](https://tauri.app/) framework
- UI components styled with [Tailwind CSS](https://tailwindcss.com/)

---

Made with ❤️ by [arach](https://github.com/arach)