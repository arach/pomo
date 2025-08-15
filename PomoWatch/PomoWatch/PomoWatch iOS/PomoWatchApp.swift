//
//  PomoWatchApp.swift
//  PomoWatch iOS
//
//  Minimal iOS bridge app to connect macOS Pomo to Apple Watch
//

import SwiftUI

@main
struct PomoWatchApp: App {
    @StateObject private var connectivityManager = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}