# Pomodoro Clock - Project Brief

## Project Overview

A simple, floating Pomodoro timer application designed to overlay on the desktop with minimal UI and maximum functionality. The app will serve as a productivity tool that can be quickly accessed and controlled without interrupting workflow.

## Core Requirements

### 1. Window Behavior

- **Floating Window**: Always-on-top window that can overlay other applications
- **Transparent Background**: Semi-transparent or fully transparent background for minimal visual interference
- **Shadow Effect**: Visual depth with drop shadow around the window
- **Collapsible Interface**: Middle-click functionality to collapse/expand the title bar and window content
- **Compact Design**: Minimal footprint when active

### 2. Global Shortcuts

- **Primary Shortcut**: Hyperkey + P to toggle window visibility
- **Quick Access**: Instant show/hide without needing to focus the application

### 3. Timer Functionality

- **Custom Duration**: User-configurable timer length (not limited to standard 25-minute Pomodoro)
- **Visual Countdown**: Clear display of remaining time
- **Timer Controls**: Start, pause, stop, and reset functionality

### 4. Audio System

- **Completion Alert**: Specific sound effect when timer reaches zero
- **Future Extensibility**: Architecture to support custom songs/sounds in later versions
- **Audio Settings**: Volume control and sound selection capabilities

### 5. User Interface

- **Minimalist Design**: Clean, distraction-free interface
- **Time Input**: Easy method to set custom timer durations
- **Status Indicators**: Clear visual feedback for timer state (running, paused, stopped)
- **Responsive Layout**: Adapts to collapsed/expanded states

## Technical Architecture

### Framework Inspiration

- **Base Architecture**: Following the same framework patterns used in the previously developed Notes app
- **Consistent Structure**: Maintaining architectural consistency across applications

### Key Components

1. **Window Manager**: Handles floating window behavior and always-on-top functionality
2. **Shortcut Handler**: Global hotkey registration and management
3. **Timer Engine**: Core countdown logic and state management
4. **Audio Controller**: Sound playback and future music integration
5. **UI Controller**: Interface rendering and user interaction handling

## Development Phases

### Phase 1 (Current Scope)

- Basic floating window with transparency
- Global shortcut implementation (Hyperkey + P)
- Custom timer duration setting
- Simple countdown display
- Basic sound alert on completion
- Middle-click collapse functionality

### Phase 2 (Future Enhancements)

- Custom sound/music selection
- Multiple timer presets
- Session tracking and statistics
- Theme customization
- Break timer integration

## User Experience Goals

- **Minimal Disruption**: Timer should enhance productivity without becoming a distraction
- **Quick Access**: Instant visibility toggle for rapid timer management
- **Intuitive Controls**: Simple, discoverable interface elements
- **Professional Appearance**: Clean design suitable for work environments

## Technical Considerations

- **Performance**: Lightweight application with minimal system resource usage
- **Compatibility**: Cross-platform functionality where applicable
- **Accessibility**: Keyboard shortcuts and clear visual indicators
- **Extensibility**: Modular design to support future feature additions

## Success Criteria

- Window consistently floats above other applications
- Global shortcut works reliably across different applications
- Timer accuracy within 1-second precision
- Smooth collapse/expand animations
- Clear audio notification at timer completion
- Intuitive time setting interface

## Notes

- Architecture should mirror the Notes app framework for consistency
- Focus on simplicity and reliability over feature complexity
- Design should support future audio customization features
