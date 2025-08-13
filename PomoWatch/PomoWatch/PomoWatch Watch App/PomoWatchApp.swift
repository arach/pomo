//
//  PomoWatchApp.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI
import AppIntents

@main
struct PomoWatch_Watch_AppApp: App {
    @StateObject private var intentManager = TimerIntentManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(intentManager)
                .onAppear {
                    // Register app shortcuts
                    PomoShortcuts.updateAppShortcutParameters()
                }
        }
    }
}
