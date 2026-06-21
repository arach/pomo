import Foundation
import SwiftUI

struct SessionRecord: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let mode: String
    let duration: TimeInterval
    let completed: Bool
}

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let sessions: Int
    let focusTime: TimeInterval
    let breaks: Int
}

class StatsManager: ObservableObject {
    @Published var sessions: [SessionRecord] = []
    @Published var weeklyStats: [DailyStats] = []
    @Published var streakDays = 0
    @Published var bestStreak = 0
    @Published var totalSessions = 0
    @Published var averageSessionsPerDay: Double = 0
    
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "sessionRecords"
    
    init() {
        loadSessions()
        calculateStats()
    }
    
    func addSession(mode: FocusMode, duration: TimeInterval, completed: Bool) {
        let session = SessionRecord(
            date: Date(),
            mode: mode.rawValue,
            duration: duration,
            completed: completed
        )
        sessions.append(session)
        saveSessions()
        calculateStats()
    }
    
    private func loadSessions() {
        if let data = userDefaults.data(forKey: sessionsKey),
           let decoded = try? JSONDecoder().decode([SessionRecord].self, from: data) {
            sessions = decoded
        }
    }
    
    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            userDefaults.set(encoded, forKey: sessionsKey)
        }
    }
    
    private func calculateStats() {
        // Calculate weekly stats
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        
        var dailyData: [Date: (sessions: Int, focusTime: TimeInterval, breaks: Int)] = [:]
        
        for session in sessions.filter({ $0.date >= weekAgo }) {
            let day = calendar.startOfDay(for: session.date)
            var data = dailyData[day] ?? (0, 0, 0)
            
            if session.mode == FocusMode.deepFocus.rawValue {
                data.sessions += 1
                data.focusTime += session.duration
            } else {
                data.breaks += 1
            }
            
            dailyData[day] = data
        }
        
        weeklyStats = dailyData.map { date, data in
            DailyStats(date: date, sessions: data.sessions, focusTime: data.focusTime, breaks: data.breaks)
        }.sorted { $0.date < $1.date }
        
        // Calculate streak
        calculateStreak()
        
        // Calculate totals
        totalSessions = sessions.filter { $0.mode == FocusMode.deepFocus.rawValue }.count
        
        if !weeklyStats.isEmpty {
            let totalDays = Double(weeklyStats.count)
            let totalWeeklySessions = weeklyStats.reduce(0) { $0 + $1.sessions }
            averageSessionsPerDay = Double(totalWeeklySessions) / totalDays
        }
    }
    
    private func calculateStreak() {
        let calendar = Calendar.current
        var currentStreak = 0
        var maxStreak = 0
        var lastDate: Date?
        
        let sortedSessions = sessions
            .filter { $0.mode == FocusMode.deepFocus.rawValue }
            .sorted { $0.date > $1.date }
        
        for session in sortedSessions {
            let sessionDay = calendar.startOfDay(for: session.date)
            
            if let last = lastDate {
                let dayDiff = calendar.dateComponents([.day], from: sessionDay, to: last).day ?? 0
                
                if dayDiff == 1 {
                    currentStreak += 1
                } else if dayDiff > 1 {
                    maxStreak = max(maxStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = sessionDay
        }
        
        streakDays = currentStreak
        bestStreak = max(maxStreak, currentStreak)
    }
    
    func clearAllData() {
        sessions = []
        saveSessions()
        calculateStats()
    }
}