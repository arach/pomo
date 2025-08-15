import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var timerManager: TimerManager
    @EnvironmentObject var statsManager: StatsManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("autoStartBreaks") private var autoStartBreaks = false
    @AppStorage("dailyGoal") private var dailyGoal = 8
    
    @State private var showingResetAlert = false
    @State private var customFocusMinutes = 25
    @State private var customBreakMinutes = 5
    
    var body: some View {
        NavigationView {
            Form {
                // Timer Settings
                Section(header: Text("Timer Settings")) {
                    HStack {
                        Label("Focus Duration", systemImage: "brain.head.profile")
                        Spacer()
                        Stepper("\(customFocusMinutes) min", value: $customFocusMinutes, in: 1...60)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Label("Break Duration", systemImage: "cup.and.saucer.fill")
                        Spacer()
                        Stepper("\(customBreakMinutes) min", value: $customBreakMinutes, in: 1...30)
                            .labelsHidden()
                    }
                    
                    Toggle(isOn: $autoStartBreaks) {
                        Label("Auto-start Breaks", systemImage: "play.circle")
                    }
                }
                
                // Notifications
                Section(header: Text("Notifications")) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Push Notifications", systemImage: "bell")
                    }
                    .onChange(of: notificationsEnabled) { enabled in
                        if enabled {
                            requestNotificationPermission()
                        }
                    }
                    
                    Toggle(isOn: $soundEnabled) {
                        Label("Sound Effects", systemImage: "speaker.wave.2")
                    }
                    
                    Toggle(isOn: $hapticEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                }
                
                // Goals
                Section(header: Text("Goals")) {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                        Spacer()
                        Stepper("\(dailyGoal) sessions", value: $dailyGoal, in: 1...20)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Label("Current Progress", systemImage: "chart.bar.fill")
                        Spacer()
                        Text("\(timerManager.dailySessions) / \(dailyGoal)")
                            .foregroundColor(.secondary)
                        
                        if timerManager.dailySessions >= dailyGoal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // About
                Section(header: Text("About")) {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://pomo.arach.dev")!) {
                        HStack {
                            Label("Website", systemImage: "globe")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://github.com/yourusername/pomo")!) {
                        HStack {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Data Management
                Section(header: Text("Data")) {
                    Button(action: { showingResetAlert = true }) {
                        Label("Clear All Data", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Clear All Data?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    statsManager.clearAllData()
                    timerManager.completedPomodoros = 0
                    timerManager.dailySessions = 0
                    timerManager.totalFocusTime = 0
                }
            } message: {
                Text("This will permanently delete all your statistics and cannot be undone.")
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if !granted {
                notificationsEnabled = false
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(TimerManager())
            .environmentObject(StatsManager())
    }
}