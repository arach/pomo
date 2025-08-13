//
//  TimerIntentManager.swift
//  PomoWatch Watch App
//
//  Manages timer state for App Intents
//

import Foundation
import SwiftUI

class TimerIntentManager: ObservableObject {
    static let shared = TimerIntentManager()
    
    @Published var timeRemaining: Int = 0
    @Published var isRunning: Bool = false
    @Published var selectedMinutes: Int = 25
    @Published var currentTheme: WatchTheme = .minimal
    
    private var timer: Timer?
    
    private init() {
        // Load saved state from UserDefaults
        loadState()
    }
    
    func startTimer(minutes: Int, theme: TimerTheme) {
        selectedMinutes = minutes
        timeRemaining = minutes * 60
        
        // Map TimerTheme to WatchTheme
        switch theme {
        case .minimal:
            currentTheme = .minimal
        case .terminal:
            currentTheme = .terminal
        case .neon:
            currentTheme = .neon
        case .retroDigital:
            currentTheme = .retroDigital
        case .lcd:
            currentTheme = .lcd
        case .glow:
            currentTheme = .glow
        }
        
        isRunning = true
        saveState()
        
        // Post notification for the app to update
        NotificationCenter.default.post(
            name: .timerStartedFromIntent,
            object: nil,
            userInfo: [
                "minutes": minutes,
                "theme": currentTheme.rawValue
            ]
        )
        
        startInternalTimer()
    }
    
    func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        saveState()
        
        NotificationCenter.default.post(name: .timerPausedFromIntent, object: nil)
    }
    
    func resumeTimer() {
        isRunning = true
        saveState()
        startInternalTimer()
        
        NotificationCenter.default.post(name: .timerResumedFromIntent, object: nil)
    }
    
    func stopTimer() {
        isRunning = false
        timeRemaining = 0
        timer?.invalidate()
        timer = nil
        saveState()
        
        NotificationCenter.default.post(name: .timerStoppedFromIntent, object: nil)
    }
    
    func getStatus() -> (isRunning: Bool, timeRemaining: Int) {
        return (isRunning, timeRemaining)
    }
    
    private func startInternalTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
                self.saveState()
            } else {
                self.stopTimer()
            }
        }
    }
    
    private func saveState() {
        UserDefaults.standard.set(timeRemaining, forKey: "intentTimeRemaining")
        UserDefaults.standard.set(isRunning, forKey: "intentIsRunning")
        UserDefaults.standard.set(selectedMinutes, forKey: "intentSelectedMinutes")
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "intentCurrentTheme")
    }
    
    private func loadState() {
        timeRemaining = UserDefaults.standard.integer(forKey: "intentTimeRemaining")
        isRunning = UserDefaults.standard.bool(forKey: "intentIsRunning")
        selectedMinutes = UserDefaults.standard.integer(forKey: "intentSelectedMinutes")
        
        if let themeString = UserDefaults.standard.string(forKey: "intentCurrentTheme"),
           let theme = WatchTheme(rawValue: themeString) {
            currentTheme = theme
        }
        
        if isRunning && timeRemaining > 0 {
            startInternalTimer()
        }
    }
}

// Notification names
extension Notification.Name {
    static let timerStartedFromIntent = Notification.Name("timerStartedFromIntent")
    static let timerPausedFromIntent = Notification.Name("timerPausedFromIntent")
    static let timerResumedFromIntent = Notification.Name("timerResumedFromIntent")
    static let timerStoppedFromIntent = Notification.Name("timerStoppedFromIntent")
}