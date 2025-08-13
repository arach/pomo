# PomoWatch - Apple Watch Companion App

A simplified, standalone watchOS app for Pomo that works independently without WatchKit dependencies.

## 📱 Features

- **Timer Modes**: Deep Focus (25min), Short Break (5min), Long Break (15min), Planning (10min)
- **Visual Progress**: Circular progress ring with time display
- **Session Tracking**: Visual dots showing completed pomodoros
- **Statistics**: Track daily sessions and total focus time
- **Mode Selection**: Quick switch between different focus modes
- **Auto-progression**: Automatically advances to breaks after focus sessions

## 🛠 Building the App

### Method 1: Create New watchOS App (Recommended)

1. **Open Xcode**
2. **Create New Project**:
   - File → New → Project
   - Choose watchOS → App
   - Product Name: "PomoWatch"
   - Interface: SwiftUI
   - Language: Swift
   - Include Notification Scene: No

3. **Replace the generated files**:
   - Delete the default `ContentView.swift`
   - Copy these files into your project:
     - `PomoWatchApp.swift`
     - `ContentView.swift`
     - `TimerManager.swift`
     - `ModeSelectionView.swift`

4. **Build and Run**:
   - Select your Apple Watch simulator or device
   - Press ⌘R to build and run

### Method 2: Add Files to Existing Project

1. **Add Swift files to your watchOS target**:
   - Drag all `.swift` files into Xcode
   - Make sure they're added to your watchOS app target

2. **Configure the app**:
   - Set minimum deployment target to watchOS 9.0
   - Ensure SwiftUI framework is linked

## 📂 Project Structure

```
PomoWatch/
├── PomoWatchApp.swift      # App entry point
├── ContentView.swift       # Main timer interface
├── TimerManager.swift      # Timer logic and state management
├── ModeSelectionView.swift # Mode selection and stats view
└── README.md              # This file
```

## 🎨 Customization

### Adding New Modes

Edit `TimerManager.swift` to add new focus modes:

```swift
enum FocusMode: String, CaseIterable {
    case yourMode = "Custom Mode"
    // ... existing modes
    
    var duration: TimeInterval {
        switch self {
        case .yourMode:
            return 20 * 60 // 20 minutes
        // ... other cases
        }
    }
}
```

### Changing Colors

Modify the color property in `FocusMode`:

```swift
var color: Color {
    switch self {
    case .deepFocus:
        return .cyan // Change to your preferred color
    // ... other cases
    }
}
```

## 🔄 App Lifecycle

The app follows this flow:
1. **Launch**: Initializes with Deep Focus mode (25 minutes)
2. **Timer Control**: Start/pause with play button
3. **Progress**: Visual ring fills as time progresses
4. **Completion**: Auto-advances to appropriate break
5. **Sessions**: After 4 focus sessions, suggests long break

## ⚠️ Known Limitations

This simplified version doesn't include:
- WatchKit-specific features (haptics, complications)
- Background refresh
- Notifications
- Digital Crown interaction

To add these features, you'll need to:
1. Import WatchKit in a watchOS project
2. Add notification permissions
3. Configure background modes
4. Implement complication data source

## 📄 License

MIT License - Part of the Pomo project

## 🤝 Contributing

Feel free to submit issues and enhancement requests!