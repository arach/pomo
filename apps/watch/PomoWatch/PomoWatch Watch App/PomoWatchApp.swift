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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var intentManager = TimerIntentManager.shared
    @StateObject private var companion = WatchCompanionController()
    
    var body: some Scene {
        WindowGroup {
            PomoWatchRootView()
                .environmentObject(intentManager)
                .environmentObject(companion)
                .onAppear {
                    // Register app shortcuts
                    PomoShortcuts.updateAppShortcutParameters()
                    companion.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        companion.refresh()
                    }
                }
        }
    }
}
