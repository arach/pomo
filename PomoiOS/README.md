# PomoiOS - iPhone Companion App

A comprehensive iPhone companion app for the Pomo productivity timer, featuring rich statistics, customizable settings, and seamless synchronization capabilities.

## 📱 Features

### Timer Functionality
- **Multiple Focus Modes**: Deep Focus (25min), Short Break (5min), Long Break (15min), Planning (10min)
- **Visual Progress Ring**: Beautiful circular progress indicator with smooth animations
- **Session Tracking**: Visual dots showing completed pomodoros
- **Smart Auto-progression**: Automatically switches between focus and break sessions

### Statistics & Analytics
- **Daily Metrics**: Track sessions completed today
- **Streak Tracking**: Monitor consecutive days of productivity
- **Weekly Charts**: Visual representation of your productivity patterns
- **Focus Time Analysis**: Detailed breakdown of time spent in deep work
- **Historical Data**: Complete session history with export capabilities

### Customization
- **Adjustable Durations**: Customize focus and break lengths (1-60 minutes)
- **Daily Goals**: Set and track personal productivity targets
- **Notification Preferences**: Control alerts, sounds, and haptic feedback
- **Auto-start Options**: Configure automatic break initiation

## 🛠 Building the App

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- Swift 5.9+
- Apple Developer account (for device testing)

### Method 1: Create New iOS App Project

1. **Open Xcode**

2. **Create New Project**:
   - File → New → Project
   - Choose iOS → App
   - Product Name: "PomoiOS"
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: No
   - Include Tests: Optional

3. **Copy Project Files**:
   ```bash
   # Remove default ContentView.swift
   rm ContentView.swift
   
   # Copy all project files maintaining folder structure
   cp -r PomoiOS/* YourProject/
   ```

4. **Configure Project**:
   - Set minimum deployment target to iOS 17.0
   - Add app icon assets
   - Configure bundle identifier (e.g., com.yourname.pomo)

5. **Build and Run**:
   - Select target device or simulator
   - Press ⌘R to build and run

### Method 2: Open as Swift Package

1. **Create Package.swift**:
   ```swift
   // swift-tools-version: 5.9
   import PackageDescription

   let package = Package(
       name: "PomoiOS",
       platforms: [.iOS(.v17)],
       products: [
           .library(name: "PomoiOS", targets: ["PomoiOS"])
       ],
       targets: [
           .target(name: "PomoiOS", path: ".")
       ]
   )
   ```

2. **Open in Xcode**:
   ```bash
   open Package.swift
   ```

## 📂 Project Structure

```
PomoiOS/
├── PomoiOSApp.swift           # App entry point
├── ContentView.swift          # Main tab view container
├── Models/
│   ├── TimerManager.swift    # Core timer logic and state
│   └── StatsManager.swift    # Statistics and data persistence
├── Views/
│   ├── TimerView.swift       # Main timer interface
│   ├── StatsView.swift       # Statistics dashboard
│   └── SettingsView.swift    # App preferences
└── README.md                  # This file
```

## 🔄 Watch Connectivity (Future)

To sync with the Apple Watch app, implement Watch Connectivity:

```swift
import WatchConnectivity

class ConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = ConnectivityManager()
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func sendTimerState(_ state: TimerState) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["timerState": state], replyHandler: nil)
    }
}
```

## 🎨 Customization Guide

### Adding New Timer Modes

Edit `TimerManager.swift`:
```swift
enum FocusMode: String, CaseIterable {
    case customMode = "Custom"
    // ... existing modes
    
    var duration: TimeInterval {
        switch self {
        case .customMode:
            return 30 * 60 // 30 minutes
        // ... other cases
        }
    }
}
```

### Theming

Modify colors in `TimerView.swift`:
```swift
var themeColor: Color {
    switch currentMode {
    case .deepFocus:
        return Color(red: 0, green: 0.8, blue: 0.8) // Custom cyan
    // ... other modes
    }
}
```

## 🔔 Notifications

The app requests notification permissions for:
- Session completion alerts
- Daily goal achievements
- Streak milestones
- Break reminders

Configure in Settings → Notifications in the app.

## 📊 Data Persistence

- **UserDefaults**: Settings and simple statistics
- **JSON Encoding**: Session history stored locally
- **Core Data**: (Optional) For more complex data requirements

## 🚀 Deployment

### TestFlight Distribution

1. Archive the app: Product → Archive
2. Upload to App Store Connect
3. Submit for TestFlight review
4. Invite testers via email or public link

### App Store Release

1. Prepare screenshots for all device sizes
2. Write compelling app description
3. Set up App Store Connect metadata
4. Submit for App Store review

## 🤝 Integration Points

### Desktop App Sync
- Implement CloudKit for cross-device sync
- Use shared container for macOS Catalyst version

### Widget Extension
- Add Widget Extension target
- Implement TimelineProvider for live updates
- Design compact and expanded widget families

### Shortcuts Integration
- Add Intents Extension
- Define custom intents for quick actions
- Enable Siri suggestions

## 📱 Device Requirements

- **iPhone**: iOS 17.0+
- **iPad**: iPadOS 17.0+ (with responsive layout)
- **Storage**: ~10 MB
- **Network**: Optional (for future sync features)

## 🐛 Troubleshooting

### Timer Not Running in Background
- iOS suspends timers when app is backgrounded
- Implement local notifications for completion alerts
- Use background tasks for periodic updates

### Stats Not Persisting
- Check UserDefaults suite configuration
- Verify app sandbox permissions
- Clear derived data if needed

## 📄 License

MIT License - Part of the Pomo project

## 🔗 Links

- [Pomo Web App](https://pomo.arach.dev)
- [Apple Watch App](../PomoWatch/README.md)
- [Desktop App](../README.md)