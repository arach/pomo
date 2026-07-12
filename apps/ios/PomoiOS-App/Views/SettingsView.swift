import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var timerManager: TimerManager
    @EnvironmentObject private var statsManager: StatsManager

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("autoStartBreaks") private var autoStartBreaks = false
    @AppStorage("dailyGoal") private var dailyGoal = 8
    @AppStorage("focusMinutes") private var focusMinutes = 25
    @AppStorage("shortBreakMinutes") private var shortBreakMinutes = 5
    @AppStorage("longBreakMinutes") private var longBreakMinutes = 15
    @AppStorage("planningMinutes") private var planningMinutes = 10
    @AppStorage("focusFace") private var faceRaw = FocusFace.chronograph.rawValue

    @State private var showingResetAlert = false
    @State private var showingNotificationAlert = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    header
                    appearance
                    durations
                    rhythm
                    feedback
                    privacy
                    about
                    dataControls
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .pomoScreen()
            .toolbar(.hidden, for: .navigationBar)
            .alert("Notifications are off", isPresented: $showingNotificationAlert) {
                Button("OK", role: .cancel) {}
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("Allow notifications in Settings to hear when a session finishes in the background.")
            }
            .alert("Clear all activity?", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    statsManager.clearAllData()
                    timerManager.completedPomodoros = 0
                }
            } message: {
                Text("This permanently removes your session history from this device.")
            }
            .onChange(of: focusMinutes) { _, _ in timerManager.applyDurationSettings() }
            .onChange(of: shortBreakMinutes) { _, _ in timerManager.applyDurationSettings() }
            .onChange(of: longBreakMinutes) { _, _ in timerManager.applyDurationSettings() }
            .onChange(of: planningMinutes) { _, _ in timerManager.applyDurationSettings() }
            .onAppear {
                if faceRaw != face.rawValue {
                    faceRaw = face.rawValue
                }
            }
        }
    }

    private var face: FocusFace {
        get { FocusFace(storedValue: faceRaw) }
        nonmutating set { faceRaw = newValue.rawValue }
    }

    private var header: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 8) {
                PomoWordmark()
                Text("Timer settings")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(PomoPalette.ink)
            }
            Spacer()
            Text("SETTINGS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(1.6)
                .foregroundStyle(PomoPalette.dim)
        }
    }

    private var durations: some View {
        VStack(spacing: 0) {
            PomoSectionLabel(title: "Durations")
                .padding(.bottom, 10)
            SettingStepper(label: "Focus", icon: "scope", value: $focusMinutes, range: 5...90, step: 5, tint: PomoPalette.accent)
            divider
            SettingStepper(label: "Short break", icon: "cup.and.saucer.fill", value: $shortBreakMinutes, range: 1...30, step: 1, tint: PomoPalette.green)
            divider
            SettingStepper(label: "Long break", icon: "figure.walk", value: $longBreakMinutes, range: 5...45, step: 5, tint: PomoPalette.blue)
            divider
            SettingStepper(label: "Planning", icon: "pencil.and.list.clipboard", value: $planningMinutes, range: 5...30, step: 5, tint: PomoPalette.orange)
        }
        .pomoPanel()
    }

    private var appearance: some View {
        FocusFacePicker(selection: Binding(get: { face }, set: { face = $0 }))
            .pomoPanel()
    }

    private var rhythm: some View {
        VStack(spacing: 0) {
            PomoSectionLabel(title: "Rhythm")
                .padding(.bottom, 10)
            SettingStepper(label: "Daily goal", icon: "target", value: $dailyGoal, range: 1...16, step: 1, suffix: "blocks", tint: PomoPalette.accent)
            divider
            Toggle(isOn: $autoStartBreaks) {
                SettingsLabel(title: "Auto-start breaks", detail: "Keep the cadence moving", icon: "arrow.triangle.2.circlepath", tint: PomoPalette.green)
            }
            .toggleStyle(PomoToggleStyle())
            .padding(.vertical, 12)
        }
        .pomoPanel()
    }

    private var feedback: some View {
        VStack(spacing: 0) {
            PomoSectionLabel(title: "Feedback")
                .padding(.bottom, 10)
            Toggle(isOn: Binding(
                get: { notificationsEnabled },
                set: { enabled in
                    if enabled { requestNotificationAccess() } else { notificationsEnabled = false }
                }
            )) {
                SettingsLabel(title: "Notifications", detail: "When a session finishes", icon: "bell.fill", tint: PomoPalette.orange)
            }
            .toggleStyle(PomoToggleStyle())
            .padding(.vertical, 12)
            divider
            Toggle(isOn: $soundEnabled) {
                SettingsLabel(title: "Sound", detail: "Completion chime", icon: "speaker.wave.2.fill", tint: PomoPalette.blue)
            }
            .toggleStyle(PomoToggleStyle())
            .padding(.vertical, 12)
            divider
            Toggle(isOn: $hapticEnabled) {
                SettingsLabel(title: "Haptics", detail: "Tactile controls", icon: "hand.tap.fill", tint: PomoPalette.green)
            }
            .toggleStyle(PomoToggleStyle())
            .padding(.vertical, 12)
        }
        .pomoPanel()
    }

    private var privacy: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 20))
                .foregroundStyle(PomoPalette.green)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                Text("Private by default")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(PomoPalette.ink)
                Text("Your intents, timer settings, and activity stay on this device. Pomo has no account and no analytics SDK.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(PomoPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pomoPanel()
    }

    private var about: some View {
        VStack(spacing: 0) {
            PomoSectionLabel(title: "About", trailing: version)
                .padding(.bottom, 10)
            Link(destination: URL(string: "https://pomo.arach.dev")!) {
                linkRow("Website", icon: "globe")
            }
            divider
            Link(destination: URL(string: "https://github.com/arach/pomo")!) {
                linkRow("Source code", icon: "chevron.left.forwardslash.chevron.right")
            }
            divider
            Link(destination: URL(string: "https://pomo.arach.dev/privacy")!) {
                linkRow("Privacy policy", icon: "hand.raised.fill")
            }
        }
        .pomoPanel()
    }

    private var dataControls: some View {
        Button(role: .destructive) {
            showingResetAlert = true
        } label: {
            Label("Clear activity data", systemImage: "trash")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.red.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.red.opacity(0.07)))
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().overlay(PomoPalette.border)
    }

    private func linkRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(PomoPalette.accent)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(PomoPalette.ink)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(PomoPalette.dim)
        }
        .padding(.vertical, 13)
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(short) (\(build))"
    }

    private func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            Task { @MainActor in
                notificationsEnabled = granted
                showingNotificationAlert = !granted
            }
        }
    }
}

private struct SettingsLabel: View {
    let title: String
    let detail: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(PomoPalette.ink)
                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(PomoPalette.dim)
            }
        }
    }
}

private struct SettingStepper: View {
    let label: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    var suffix = "min"
    let tint: Color

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(PomoPalette.ink)
            Spacer()
            HStack(spacing: 5) {
                control("minus", enabled: value - step >= range.lowerBound) {
                    value = max(value - step, range.lowerBound)
                }
                Text("\(value) \(suffix)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(PomoPalette.ink)
                    .frame(minWidth: 62)
                control("plus", enabled: value + step <= range.upperBound) {
                    value = min(value + step, range.upperBound)
                }
            }
        }
        .padding(.vertical, 11)
    }

    private func control(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(enabled ? PomoPalette.ink : PomoPalette.dim.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(Circle().fill(PomoPalette.surfaceStrong))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

#Preview {
    SettingsView()
        .environmentObject(TimerManager())
        .environmentObject(StatsManager())
}
