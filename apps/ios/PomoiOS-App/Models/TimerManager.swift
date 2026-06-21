import Foundation
import SwiftUI
import Combine

enum FocusMode: String, CaseIterable {
    case deepFocus = "Deep Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case planning = "Planning"
    
    var duration: TimeInterval {
        switch self {
        case .deepFocus:
            return 25 * 60
        case .shortBreak:
            return 5 * 60
        case .longBreak:
            return 15 * 60
        case .planning:
            return 10 * 60
        }
    }
    
    var color: Color {
        switch self {
        case .deepFocus:
            return .cyan
        case .shortBreak:
            return .green
        case .longBreak:
            return .blue
        case .planning:
            return .purple
        }
    }
    
    var icon: String {
        switch self {
        case .deepFocus:
            return "brain.head.profile"
        case .shortBreak:
            return "cup.and.saucer.fill"
        case .longBreak:
            return "figure.walk"
        case .planning:
            return "pencil.and.outline"
        }
    }
}

class TimerManager: ObservableObject {
    @Published var currentMode: FocusMode = .deepFocus
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var isActive = false
    @Published var completedPomodoros = 0
    @Published var dailySessions = 0
    @Published var totalFocusTime: TimeInterval = 0
    @Published var showingCompletion = false
    
    private var timer: Timer?
    private var sessionStartTime: Date?
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadStats()
        timeRemaining = currentMode.duration
    }
    
    func startTimer() {
        guard !isActive else { return }
        isActive = true
        sessionStartTime = Date()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.completeSession()
            }
        }
    }
    
    func pauseTimer() {
        isActive = false
        timer?.invalidate()
        timer = nil
        
        // Track partial session time
        if let startTime = sessionStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if currentMode == .deepFocus {
                totalFocusTime += elapsed
                saveStats()
            }
        }
        sessionStartTime = nil
    }
    
    func resetTimer() {
        pauseTimer()
        timeRemaining = currentMode.duration
        showingCompletion = false
    }
    
    func skipToNext() {
        completeSession()
    }
    
    private func completeSession() {
        pauseTimer()
        showingCompletion = true
        
        // Update stats
        if currentMode == .deepFocus {
            completedPomodoros += 1
            dailySessions += 1
            if let startTime = sessionStartTime {
                totalFocusTime += currentMode.duration
            }
        }
        
        // Auto-advance to next mode
        if currentMode == .deepFocus {
            if completedPomodoros % 4 == 0 {
                switchToMode(.longBreak)
            } else {
                switchToMode(.shortBreak)
            }
        } else {
            switchToMode(.deepFocus)
        }
        
        saveStats()
        
        // Send notification
        sendCompletionNotification()
    }
    
    func switchToMode(_ mode: FocusMode) {
        pauseTimer()
        currentMode = mode
        timeRemaining = mode.duration
        showingCompletion = false
    }
    
    private func sendCompletionNotification() {
        // Will implement with UserNotifications framework
    }
    
    private func loadStats() {
        completedPomodoros = userDefaults.integer(forKey: "completedPomodoros")
        dailySessions = userDefaults.integer(forKey: "dailySessions")
        totalFocusTime = userDefaults.double(forKey: "totalFocusTime")
        
        // Reset daily stats if it's a new day
        if let lastDate = userDefaults.object(forKey: "lastSessionDate") as? Date {
            if !Calendar.current.isDateInToday(lastDate) {
                dailySessions = 0
                userDefaults.set(dailySessions, forKey: "dailySessions")
            }
        }
    }
    
    private func saveStats() {
        userDefaults.set(completedPomodoros, forKey: "completedPomodoros")
        userDefaults.set(dailySessions, forKey: "dailySessions")
        userDefaults.set(totalFocusTime, forKey: "totalFocusTime")
        userDefaults.set(Date(), forKey: "lastSessionDate")
    }
    
    var progress: Double {
        let total = currentMode.duration
        let elapsed = total - timeRemaining
        return elapsed / total
    }
    
    var formattedTime: String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}