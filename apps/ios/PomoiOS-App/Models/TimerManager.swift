import Combine
import Foundation
import SwiftUI
import UIKit
import UserNotifications

enum FocusMode: String, CaseIterable, Codable, Identifiable {
    case deepFocus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    case planning = "Planning"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .deepFocus: PomoPalette.accent
        case .shortBreak: PomoPalette.green
        case .longBreak: PomoPalette.blue
        case .planning: PomoPalette.orange
        }
    }

    var icon: String {
        switch self {
        case .deepFocus: "scope"
        case .shortBreak: "cup.and.saucer.fill"
        case .longBreak: "figure.walk"
        case .planning: "pencil.and.list.clipboard"
        }
    }

    var label: String {
        switch self {
        case .deepFocus: "FOCUS"
        case .shortBreak: "SHORT BREAK"
        case .longBreak: "LONG BREAK"
        case .planning: "PLANNING"
        }
    }

    var liveActivityAccentHex: UInt32 {
        switch self {
        case .deepFocus: 0xEAE434
        case .shortBreak: 0x5ED69A
        case .longBreak: 0x70B7FF
        case .planning: 0xF2A65A
        }
    }
}

struct SessionOutcome: Identifiable, Equatable {
    let id = UUID()
    let mode: FocusMode
    let duration: TimeInterval
    let intent: String?
    let completedAt: Date
    let nextMode: FocusMode
    let nextDuration: TimeInterval
    let cadenceFilled: Int
    let closedCadenceSet: Bool
    let autoStartedNext: Bool
}

@MainActor
final class TimerManager: ObservableObject {
    typealias CompletionHandler = (FocusMode, TimeInterval, Bool, String?) -> Void

    @Published var currentMode: FocusMode = .deepFocus
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published private(set) var sessionDuration: TimeInterval = 25 * 60
    @Published var isActive = false
    @Published var completedPomodoros = 0
    @Published private(set) var outcome: SessionOutcome?
    @Published private(set) var stateRevision = 0
    @Published var intent = ""

    var onSessionEnded: CompletionHandler?

    private let defaults = UserDefaults.standard
    private var expectedEndDate: Date?
    private var ticker: AnyCancellable?
    private let notificationIdentifier = "pomo.session.complete"
    private let liveActivity = PomoLiveActivityController()
    private let completionSound = CompletionSoundController()
    private let activeEndDateKey = "activeTimerEndDate"
    private let activeModeKey = "activeTimerMode"
    private let activeIntentKey = "activeTimerIntent"
    private let activeDurationKey = "activeTimerDuration"

    init() {
        completedPomodoros = defaults.integer(forKey: "completedPomodoros")
        timeRemaining = duration(for: currentMode)
        sessionDuration = timeRemaining

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-appStorePreview") {
            timeRemaining = 19 * 60 + 10
            sessionDuration = 25 * 60
            intent = "Finish the release checklist"
            completedPomodoros = 3

            if ProcessInfo.processInfo.arguments.contains("-previewCompletion") {
                currentMode = .shortBreak
                timeRemaining = 5 * 60
                sessionDuration = 5 * 60
                intent = ""
                outcome = SessionOutcome(
                    mode: .deepFocus,
                    duration: 25 * 60,
                    intent: "Finish the release checklist",
                    completedAt: Date(),
                    nextMode: .shortBreak,
                    nextDuration: 5 * 60,
                    cadenceFilled: 3,
                    closedCadenceSet: false,
                    autoStartedNext: false
                )
            }
            return
        }
        #endif

        restoreActiveSession()
    }

    deinit {
        ticker?.cancel()
    }

    func duration(for mode: FocusMode) -> TimeInterval {
        let key: String
        let fallback: Int
        switch mode {
        case .deepFocus:
            key = "focusMinutes"
            fallback = 25
        case .shortBreak:
            key = "shortBreakMinutes"
            fallback = 5
        case .longBreak:
            key = "longBreakMinutes"
            fallback = 15
        case .planning:
            key = "planningMinutes"
            fallback = 10
        }
        let stored = defaults.integer(forKey: key)
        return TimeInterval((stored == 0 ? fallback : stored) * 60)
    }

    func startTimer() {
        guard !isActive, timeRemaining > 0 else { return }
        isActive = true
        expectedEndDate = Date().addingTimeInterval(timeRemaining)
        startTicker()
        scheduleCompletionNotification()
        persistActiveSession()
        liveActivity.startOrResume(
            modeName: currentMode.label,
            intent: intent,
            remaining: timeRemaining,
            total: sessionDuration,
            accentHex: currentMode.liveActivityAccentHex
        )
        haptic(.medium)
        stateRevision &+= 1
    }

    func pauseTimer() {
        guard isActive else { return }
        refreshClock()
        isActive = false
        expectedEndDate = nil
        ticker?.cancel()
        ticker = nil
        cancelCompletionNotification()
        clearActiveSessionPersistence()
        liveActivity.pause(remaining: timeRemaining, intent: intent)
        haptic(.light)
        stateRevision &+= 1
    }

    func resetTimer() {
        liveActivity.end(remaining: timeRemaining, immediate: true)
        stopClock()
        timeRemaining = sessionDuration
        outcome = nil
        haptic(.light)
        stateRevision &+= 1
    }

    func skipToNext() {
        endSession(completed: false, showCelebration: false)
    }

    func switchToMode(_ mode: FocusMode) {
        liveActivity.end(remaining: timeRemaining, immediate: true)
        stopClock()
        currentMode = mode
        sessionDuration = duration(for: mode)
        timeRemaining = sessionDuration
        outcome = nil
        stateRevision &+= 1
    }

    func applyDurationSettings() {
        guard !isActive else { return }
        sessionDuration = duration(for: currentMode)
        timeRemaining = sessionDuration
        stateRevision &+= 1
    }

    func setSessionDuration(_ duration: TimeInterval) {
        guard !isActive else { return }
        sessionDuration = min(max(duration.rounded(), 1), 120 * 60 + 59)
        timeRemaining = sessionDuration
        outcome = nil
        haptic(.light)
        stateRevision &+= 1
    }

    func dismissOutcome(startNext: Bool) {
        outcome = nil
        if startNext, !isActive {
            startTimer()
        } else {
            stateRevision &+= 1
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        if phase == .active,
           let completedAt = outcome?.completedAt,
           Date().timeIntervalSince(completedAt) > 2 * 60 * 60 {
            outcome = nil
        }
        guard phase == .active, isActive else { return }
        refreshClock()
    }

    var progress: Double {
        let total = sessionDuration
        guard total > 0 else { return 0 }
        return min(max((total - timeRemaining) / total, 0), 1)
    }

    var formattedTime: String {
        let secondsRemaining = max(Int(timeRemaining.rounded(.up)), 0)
        return String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    var sessionDurationLabel: String {
        let seconds = max(Int(sessionDuration.rounded()), 1)
        if seconds.isMultiple(of: 60) {
            return "\(seconds / 60) MIN"
        }
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshClock()
            }
    }

    private func refreshClock() {
        guard isActive, let expectedEndDate else { return }
        timeRemaining = max(expectedEndDate.timeIntervalSinceNow, 0)
        if timeRemaining <= 0 {
            endSession(completed: true, showCelebration: true)
        }
    }

    private func endSession(completed: Bool, showCelebration: Bool) {
        let finishedMode = currentMode
        let finishedDuration = sessionDuration
        let finishedIntent = intent.trimmingCharacters(in: .whitespacesAndNewlines)

        liveActivity.end(remaining: completed ? 0 : timeRemaining, immediate: !completed)
        stopClock()

        if completed, finishedMode == .deepFocus {
            completedPomodoros += 1
            defaults.set(completedPomodoros, forKey: "completedPomodoros")
        }

        onSessionEnded?(finishedMode, finishedDuration, completed, finishedIntent.isEmpty ? nil : finishedIntent)

        if finishedMode == .deepFocus {
            currentMode = completedPomodoros > 0 && completedPomodoros % 4 == 0 ? .longBreak : .shortBreak
        } else {
            currentMode = .deepFocus
        }
        sessionDuration = duration(for: currentMode)
        timeRemaining = sessionDuration
        intent = ""

        let shouldAutoStartBreak = defaults.bool(forKey: "autoStartBreaks") && currentMode != .deepFocus

        if showCelebration {
            let closedCadenceSet = finishedMode == .deepFocus
                && completedPomodoros > 0
                && completedPomodoros.isMultiple(of: 4)
            let cadenceFilled = finishedMode == .deepFocus
                ? (closedCadenceSet ? 4 : max(completedPomodoros % 4, 1))
                : completedPomodoros % 4
            outcome = SessionOutcome(
                mode: finishedMode,
                duration: finishedDuration,
                intent: finishedIntent.isEmpty ? nil : finishedIntent,
                completedAt: Date(),
                nextMode: currentMode,
                nextDuration: sessionDuration,
                cadenceFilled: cadenceFilled,
                closedCadenceSet: closedCadenceSet,
                autoStartedNext: shouldAutoStartBreak
            )
        }

        if shouldAutoStartBreak {
            startTimer()
        }

        if showCelebration {
            let soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
            if soundEnabled, UIApplication.shared.applicationState == .active {
                completionSound.play()
            }
            haptic(.success)
        }
        stateRevision &+= 1
    }

    private func stopClock() {
        isActive = false
        expectedEndDate = nil
        ticker?.cancel()
        ticker = nil
        cancelCompletionNotification()
        clearActiveSessionPersistence()
    }

    private func persistActiveSession() {
        guard let expectedEndDate else { return }
        defaults.set(expectedEndDate, forKey: activeEndDateKey)
        defaults.set(currentMode.rawValue, forKey: activeModeKey)
        defaults.set(intent, forKey: activeIntentKey)
        defaults.set(sessionDuration, forKey: activeDurationKey)
    }

    private func clearActiveSessionPersistence() {
        defaults.removeObject(forKey: activeEndDateKey)
        defaults.removeObject(forKey: activeModeKey)
        defaults.removeObject(forKey: activeIntentKey)
        defaults.removeObject(forKey: activeDurationKey)
    }

    private func restoreActiveSession() {
        guard
            let endDate = defaults.object(forKey: activeEndDateKey) as? Date,
            let modeRaw = defaults.string(forKey: activeModeKey),
            let mode = FocusMode(rawValue: modeRaw)
        else {
            liveActivity.end(immediate: true)
            return
        }

        let remaining = endDate.timeIntervalSinceNow
        guard remaining > 0 else {
            clearActiveSessionPersistence()
            liveActivity.end(immediate: true)
            return
        }

        currentMode = mode
        timeRemaining = remaining
        let storedDuration = defaults.double(forKey: activeDurationKey)
        sessionDuration = storedDuration > 0 ? max(storedDuration, remaining) : duration(for: mode)
        isActive = true
        expectedEndDate = endDate
        intent = defaults.string(forKey: activeIntentKey) ?? ""
        startTicker()
        liveActivity.startOrResume(
            modeName: mode.label,
            intent: intent,
            remaining: remaining,
            total: sessionDuration,
            accentHex: mode.liveActivityAccentHex
        )
        stateRevision &+= 1
    }

    func sharedSessionState() -> SharedSessionState {
        SharedSessionState(
            mode: currentMode.rawValue,
            intent: intent.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: sessionDuration,
            remaining: timeRemaining,
            endDate: isActive ? Date().addingTimeInterval(timeRemaining) : nil,
            isRunning: isActive,
            completedFocusBlocks: completedPomodoros,
            updatedAt: Date(),
            outcome: outcome.map {
                SharedSessionOutcome(
                    mode: $0.mode.rawValue,
                    duration: $0.duration,
                    intent: $0.intent,
                    completedAt: $0.completedAt,
                    nextMode: $0.nextMode.rawValue,
                    nextDuration: $0.nextDuration,
                    cadenceFilled: $0.cadenceFilled,
                    closedCadenceSet: $0.closedCadenceSet,
                    autoStartedNext: $0.autoStartedNext
                )
            }
        )
    }

    private func scheduleCompletionNotification() {
        guard defaults.object(forKey: "notificationsEnabled") as? Bool ?? false else { return }

        let content = UNMutableNotificationContent()
        content.title = currentMode == .deepFocus ? "Focus block complete" : "Break complete"
        if currentMode == .deepFocus {
            let minutes = max(Int(sessionDuration.rounded()) / 60, 1)
            let held = "\(minutes) minute\(minutes == 1 ? "" : "s") held."
            let trimmedIntent = intent.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = trimmedIntent.isEmpty ? held : "\(trimmedIntent) · \(held)"
        } else {
            content.body = "Your next focus block is ready."
        }
        let soundEnabled = defaults.object(forKey: "soundEnabled") as? Bool ?? true
        content.sound = soundEnabled ? .default : nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(timeRemaining, 1), repeats: false)
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelCompletionNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    private enum HapticKind {
        case light, medium, success
    }

    private func haptic(_ kind: HapticKind) {
        guard defaults.object(forKey: "hapticEnabled") as? Bool ?? true else { return }
        switch kind {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
