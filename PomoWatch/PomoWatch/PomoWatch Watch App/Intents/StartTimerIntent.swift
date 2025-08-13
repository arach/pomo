//
//  StartTimerIntent.swift
//  PomoWatch Watch App
//
//  App Intent for starting a Pomodoro timer via Siri or shortcuts
//

import AppIntents
import SwiftUI

// Duration enum for App Intents
enum TimerDuration: Int, AppEnum {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case twentyFive = 25
    case thirty = 30
    case fortyFive = 45
    case sixty = 60
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Timer Duration")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .five: "5 minutes",
        .ten: "10 minutes",
        .fifteen: "15 minutes",
        .twenty: "20 minutes",
        .twentyFive: "25 minutes",
        .thirty: "30 minutes",
        .fortyFive: "45 minutes",
        .sixty: "60 minutes"
    ]
}

struct StartTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro Timer"
    static var description = IntentDescription("Start a Pomodoro timer with a specified duration")
    
    @Parameter(title: "Duration", default: .twentyFive)
    var duration: TimerDuration
    
    @Parameter(title: "Theme", default: .minimal)
    var theme: TimerTheme
    
    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$duration) timer") {
            \.$theme
        }
    }
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let minutes = duration.rawValue
        // Update shared timer state
        TimerIntentManager.shared.startTimer(minutes: minutes, theme: theme)
        
        return .result(
            value: "Started \(minutes) minute timer",
            dialog: "Starting your \(minutes) minute Pomodoro timer"
        )
    }
}

// Theme enum for App Intents
enum TimerTheme: String, AppEnum {
    case minimal = "minimal"
    case terminal = "terminal"
    case neon = "neon"
    case retroDigital = "retro"
    case lcd = "lcd"
    case glow = "glow"
    
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Timer Theme")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .minimal: "Minimal",
        .terminal: "Terminal",
        .neon: "Neon",
        .retroDigital: "Retro Digital",
        .lcd: "LCD",
        .glow: "Glow"
    ]
}

// Quick actions for common durations
struct Start25MinuteTimerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start 25 Minute Timer"
    static var description = IntentDescription("Start a standard 25-minute Pomodoro timer")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerIntentManager.shared.startTimer(minutes: 25, theme: .minimal)
        
        return .result(dialog: "Starting 25-minute Pomodoro timer")
    }
}

struct Start5MinuteBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Start 5 Minute Break"
    static var description = IntentDescription("Start a 5-minute break timer")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult & ProvidesDialog {
        TimerIntentManager.shared.startTimer(minutes: 5, theme: .minimal)
        
        return .result(dialog: "Starting 5-minute break")
    }
}