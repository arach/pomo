//
//  TimerControlIntents.swift
//  PomoWatch Watch App
//
//  App Intents for controlling the timer
//

import AppIntents
import SwiftUI

struct PauseTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Timer"
    static var description = IntentDescription("Pause the current Pomodoro timer")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerIntentManager.shared.pauseTimer()
        
        return .result(dialog: "Timer paused")
    }
}

struct ResumeTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Timer"
    static var description = IntentDescription("Resume the paused Pomodoro timer")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerIntentManager.shared.resumeTimer()
        
        return .result(dialog: "Timer resumed")
    }
}

struct StopTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Timer"
    static var description = IntentDescription("Stop and reset the current timer")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerIntentManager.shared.stopTimer()
        
        return .result(dialog: "Timer stopped")
    }
}

struct GetTimerStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Timer Status"
    static var description = IntentDescription("Check the current timer status")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let status = TimerIntentManager.shared.getStatus()
        
        if status.isRunning {
            let minutes = status.timeRemaining / 60
            let seconds = status.timeRemaining % 60
            let timeString = String(format: "%d minutes and %d seconds", minutes, seconds)
            
            return .result(
                value: timeString,
                dialog: "\(timeString) remaining in your Pomodoro"
            )
        } else {
            return .result(
                value: "No timer running",
                dialog: "No timer is currently running"
            )
        }
    }
}