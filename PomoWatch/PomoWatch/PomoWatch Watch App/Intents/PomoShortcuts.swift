//
//  PomoShortcuts.swift
//  PomoWatch Watch App
//
//  Defines app shortcuts for Siri and Shortcuts app
//

import AppIntents

struct PomoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: Start25MinuteTimerIntent(),
            phrases: [
                "Start Pomodoro in \(.applicationName)",
                "Start focus time in \(.applicationName)",
                "Begin Pomodoro with \(.applicationName)",
                "Start working with \(.applicationName)"
            ],
            shortTitle: "Start Pomodoro",
            systemImageName: "timer"
        )
        
        AppShortcut(
            intent: Start5MinuteBreakIntent(),
            phrases: [
                "Start break in \(.applicationName)",
                "Take a break with \(.applicationName)",
                "Break time in \(.applicationName)"
            ],
            shortTitle: "Start Break",
            systemImageName: "cup.and.saucer.fill"
        )
        
        AppShortcut(
            intent: PauseTimerIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Pause timer in \(.applicationName)",
                "Pause Pomodoro in \(.applicationName)"
            ],
            shortTitle: "Pause Timer",
            systemImageName: "pause.fill"
        )
        
        AppShortcut(
            intent: ResumeTimerIntent(),
            phrases: [
                "Resume \(.applicationName)",
                "Resume timer in \(.applicationName)",
                "Continue Pomodoro in \(.applicationName)"
            ],
            shortTitle: "Resume Timer",
            systemImageName: "play.fill"
        )
        
        AppShortcut(
            intent: GetTimerStatusIntent(),
            phrases: [
                "How much time left in \(.applicationName)",
                "Check \(.applicationName) timer",
                "What's my Pomodoro status in \(.applicationName)",
                "Time remaining in \(.applicationName)"
            ],
            shortTitle: "Check Timer",
            systemImageName: "clock"
        )
        
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start \(\.$duration) timer in \(.applicationName)",
                "Start \(\.$duration) Pomodoro in \(.applicationName)"
            ],
            shortTitle: "Custom Timer",
            systemImageName: "timer"
        )
    }
    
    static var shortcutTileColor: ShortcutTileColor = .blue
}