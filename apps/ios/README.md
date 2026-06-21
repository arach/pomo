# Pomo — iOS

A SwiftUI iPhone companion for Pomo: a focus timer with session stats and
settings.

## Build

Open `PomoiOS-App.xcodeproj` in Xcode and run the `PomoiOS-App` scheme on an
iOS Simulator or device.

## Structure

```
PomoiOS-App/
  PomoiOS_AppApp.swift     @main entry point
  ContentView.swift        root view
  Models/
    TimerManager.swift      countdown + session flow
    StatsManager.swift      daily session / focus-time tracking
  Views/
    TimerView.swift         the timer screen
    StatsView.swift         stats screen
    SettingsView.swift      durations & preferences
```

> Part of the [Pomo monorepo](../../README.md). The actively-developed
> implementation is the macOS app under [`apps/macos`](../macos).
