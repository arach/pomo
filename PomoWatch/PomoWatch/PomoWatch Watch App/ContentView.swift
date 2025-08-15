//
//  ContentView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI
import WatchKit
import AVFoundation
import UserNotifications

struct ContentView: View {
    // Timer state using Date-based calculation
    @State private var endTime: Date?
    @State private var pausedRemainingTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var isPaused = false
    @State private var timer: Timer?
    @State private var extendedSession: WKExtendedRuntimeSession?
    @State private var sessionHandler = ExtendedRuntimeSessionHandler()
    @State private var currentTime = Date() // Force UI updates
    
    // UI state
    @State private var currentTheme: WatchTheme = .minimal
    @State private var showThemePicker = false
    @State private var showDurationPicker = false
    @State private var sessionsCompleted = 0
    @State private var selectedMinutes = 25
    @State private var activityType: ActivityType = .focus
    @State private var showActivityTypeChange = false
    @State private var showConfetti = false
    
    // Persistence
    @AppStorage("hasSetDurationOnce") private var hasSetDurationOnce: Bool = false
    @AppStorage("timerEndTime") private var persistedEndTime: Double = 0
    @AppStorage("timerPausedTime") private var persistedPausedTime: Double = 0
    @AppStorage("timerIsRunning") private var persistedIsRunning: Bool = false
    @AppStorage("timerIsPaused") private var persistedIsPaused: Bool = false
    @AppStorage("timerSelectedMinutes") private var persistedSelectedMinutes: Int = 25
    
    @EnvironmentObject var intentManager: TimerIntentManager
    
    enum ActivityType: String, CaseIterable {
        case focus = "DEEP FOCUS"
        case shortBreak = "SHORT BREAK"
        case longBreak = "LONG BREAK"
        case planning = "PLANNING"
        
        var displayText: (String, String) {
            switch self {
            case .focus:
                return ("DEEP", "FOCUS")
            case .shortBreak:
                return ("SHORT", "BREAK")
            case .longBreak:
                return ("LONG", "BREAK")
            case .planning:
                return ("", "PLANNING")
            }
        }
    }
    
    
    // Computed properties
    var timeRemaining: Int {
        // Use currentTime to ensure view updates
        _ = currentTime
        
        if let endTime = endTime, isRunning {
            // Timer is running - calculate from end time
            let remaining = endTime.timeIntervalSinceNow
            return max(0, Int(remaining))
        } else if isPaused && pausedRemainingTime > 0 {
            // Timer is paused - show stored remaining time
            return Int(pausedRemainingTime)
        } else {
            // Timer hasn't started or was reset
            return selectedMinutes * 60
        }
    }
    
    var totalDuration: Int {
        selectedMinutes * 60
    }
    
    var progress: Double {
        Double(totalDuration - timeRemaining) / Double(totalDuration)
    }
    
    var isIdle: Bool {
        !isRunning && !isPaused && endTime == nil
    }
    
    var body: some View {
        NavigationStack {
            mainContent
        }
        .environment(\.scenePhase, scenePhase)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            // Background
            currentTheme.backgroundColor
                .ignoresSafeArea()
            
            ScrollView {
                mainScrollContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(content: controlButtonsOverlay)
        .sheet(isPresented: $showThemePicker) {
            ThemePickerView(currentTheme: $currentTheme)
        }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerView(selectedMinutes: $selectedMinutes)
        }
        .overlay(alignment: .top, content: activityChangeOverlay)
        .overlay(content: confettiOverlay)
        .onReceive(NotificationCenter.default.publisher(for: .timerStartedFromIntent), perform: handleTimerStartIntent)
        .onReceive(NotificationCenter.default.publisher(for: .timerPausedFromIntent)) { _ in
            pauseTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timerResumedFromIntent)) { _ in
            resumeTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .timerStoppedFromIntent)) { _ in
            stopTimer()
        }
        .onAppear {
            requestNotificationPermissions()
            restoreTimerState()
        }
        .onChange(of: scenePhase, perform: handleScenePhaseChange)
    }
    
    @ViewBuilder
    private func controlButtonsOverlay() -> some View {
        GeometryReader { proxy in
            controlButtons(in: proxy.size)
        }
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private func controlButtons(in size: CGSize) -> some View {
        let minDim = min(size.width, size.height)
        let edgePadding: CGFloat = max(6, minDim * 0.03) + 6
        let smallRadius: CGFloat = max(14, min(17, minDim * 0.085))
        let largeRadius: CGFloat = smallRadius
        
        ZStack {
            if currentTheme != .terminal {
                resetButton(smallRadius: smallRadius, size: size, edgePadding: edgePadding)
                playPauseButton(largeRadius: largeRadius, size: size, edgePadding: edgePadding)
            }
        }
    }
    
    @ViewBuilder
    private func resetButton(smallRadius: CGFloat, size: CGSize, edgePadding: CGFloat) -> some View {
        Group {
            if currentTheme == .minimal {
                CornerCircleButton(
                    icon: "arrow.counterclockwise",
                    size: smallRadius * 2,
                    fill: currentTheme.buttonColor,
                    border: currentTheme.buttonBorderColor,
                    iconColor: currentTheme.buttonIconColor,
                    shadowColor: currentTheme.buttonShadowColor,
                    action: { stopTimer() }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6)
                        .onEnded { _ in
                            hasSetDurationOnce = false
                            WKInterfaceDevice.current().play(.success)
                        }
                )
            } else {
                CornerCircleButton(
                    icon: "arrow.counterclockwise",
                    size: smallRadius * 2,
                    fill: currentTheme.buttonColor,
                    border: currentTheme.buttonBorderColor,
                    iconColor: currentTheme.buttonIconColor,
                    shadowColor: currentTheme.buttonShadowColor,
                    action: { stopTimer() }
                )
            }
        }
        .position(cornerPoint(.bottomLeft, in: size, controlRadius: smallRadius, edgePadding: edgePadding))
    }
    
    @ViewBuilder
    private func playPauseButton(largeRadius: CGFloat, size: CGSize, edgePadding: CGFloat) -> some View {
        CornerCircleButton(
            icon: isRunning ? "pause.fill" : "play.fill",
            size: largeRadius * 2,
            fill: isRunning ? currentTheme.accentColor : currentTheme.buttonColor,
            border: currentTheme.buttonBorderColor,
            iconColor: currentTheme.buttonIconColor,
            shadowColor: currentTheme.buttonShadowColor,
            action: { toggleTimer() }
        )
        .position(cornerPoint(.bottomRight, in: size, controlRadius: largeRadius, edgePadding: edgePadding))
    }
    
    @ViewBuilder
    private func activityChangeOverlay() -> some View {
        if showActivityTypeChange {
            Text(activityType.rawValue)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.9))
                )
                .foregroundColor(.white)
                .transition(.scale.combined(with: .opacity))
                .padding(.top, 10)
        }
    }
    
    @ViewBuilder
    private func confettiOverlay() -> some View {
        if showConfetti {
            ConfettiView(isShowing: $showConfetti)
                .allowsHitTesting(false)
        }
    }
    
    private func handleTimerStartIntent(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let minutes = userInfo["minutes"] as? Int,
           let themeString = userInfo["theme"] as? String,
           let theme = WatchTheme(rawValue: themeString) {
            selectedMinutes = minutes
            currentTheme = theme
            isRunning = true
            startInternalTimer()
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            checkTimerCompletion()
            // Restart UI updates if timer is running
            if isRunning && timer == nil {
                startInternalTimer()
            }
        } else if newPhase == .background {
            persistTimerState()
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase
    
    private func startInternalTimer() {
        // Only update UI, don't manage actual timing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            // Update currentTime to trigger view refresh
            self.currentTime = Date()
            
            // Check if timer finished
            if self.timeRemaining <= 0 && self.isRunning {
                // Timer finished
                self.completeTimer()
            }
        }
    }
    
    private func pauseTimer() {
        guard isRunning, let endTime = endTime else { return }
        
        // Store remaining time
        pausedRemainingTime = max(0, endTime.timeIntervalSinceNow)
        
        // Update state
        isRunning = false
        isPaused = true
        self.endTime = nil
        
        // Stop UI updates
        timer?.invalidate()
        timer = nil
        
        // Cancel notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // End extended session
        extendedSession?.invalidate()
        extendedSession = nil
        
        // Persist state
        persistTimerState()
    }
    
    private func resumeTimer() {
        guard isPaused, pausedRemainingTime > 0 else { return }
        
        // Calculate new end time
        endTime = Date().addingTimeInterval(pausedRemainingTime)
        
        // Update state
        isRunning = true
        isPaused = false
        pausedRemainingTime = 0
        
        // Schedule notification
        scheduleCompletionNotification()
        
        // Start extended session
        startExtendedSession()
        
        // Start UI updates
        startInternalTimer()
        
        // Persist state
        persistTimerState()
    }
    
    private func stopTimer() {
        // Reset everything
        endTime = nil
        pausedRemainingTime = 0
        isRunning = false
        isPaused = false
        
        // Stop UI updates
        timer?.invalidate()
        timer = nil
        
        // Cancel notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // End extended session
        extendedSession?.invalidate()
        extendedSession = nil
        
        // Clear persisted state
        persistedEndTime = 0
        persistedPausedTime = 0
        persistedIsRunning = false
        persistedIsPaused = false
    }
    
    private func toggleTimer() {
        if isRunning {
            pauseTimer()
        } else if isPaused {
            resumeTimer()
        } else {
            startTimer()
        }
    }
    
    private func startTimer() {
        // Calculate end time
        let duration = TimeInterval(selectedMinutes * 60)
        endTime = Date().addingTimeInterval(duration)
        
        // Update state
        isRunning = true
        isPaused = false
        pausedRemainingTime = 0
        
        // Schedule notification
        scheduleCompletionNotification()
        
        // Start extended session for background updates
        startExtendedSession()
        
        // Start UI update timer
        startInternalTimer()
        
        // Persist state
        persistTimerState()
    }
    
    private func completeTimer() {
        // Timer finished
        timer?.invalidate()
        timer = nil
        isRunning = false
        isPaused = false
        endTime = nil
        pausedRemainingTime = 0
        sessionsCompleted += 1
        
        // End extended session
        extendedSession?.invalidate()
        extendedSession = nil
        
        // Clear persisted state
        persistedEndTime = 0
        persistedPausedTime = 0
        persistedIsRunning = false
        persistedIsPaused = false
        
        // Trigger completion effects
        triggerCompletionEffects()
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func cycleActivityType() {
        let allCases = ActivityType.allCases
        if let currentIndex = allCases.firstIndex(of: activityType) {
            let nextIndex = (currentIndex + 1) % allCases.count
            activityType = allCases[nextIndex]
            
            // Adjust duration based on activity type
            switch activityType {
            case .focus:
                selectedMinutes = 25
            case .shortBreak:
                selectedMinutes = 5
            case .longBreak:
                selectedMinutes = 15
            case .planning:
                selectedMinutes = 10
            }
            // Timer will reset with new duration on next start
            
            // Haptic feedback
            WKInterfaceDevice.current().play(.click)
        }
    }
    
    private func triggerCompletionEffects() {
        // 1. Play sound effect (includes haptic feedback)
        SoundPlayer.shared.playCompletionSound()
        
        // 2. Additional haptic celebration pattern
        playHapticCelebration()
        
        // 3. Show confetti animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showConfetti = true
        }
        
        // Hide confetti after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                showConfetti = false
            }
        }
    }
    
    private func playHapticCelebration() {
        // Play a celebratory haptic pattern
        let device = WKInterfaceDevice.current()
        
        // Play a series of haptic taps to create a celebration effect
        device.play(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            device.play(.directionUp)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            device.play(.success)
        }
    }
    
    // MARK: - Notification Methods
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permissions: \(error)")
            }
        }
    }
    
    private func scheduleCompletionNotification() {
        guard let endTime = endTime else { return }
        
        // Cancel existing notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete!"
        content.body = "Your \(activityType.rawValue) session is finished."
        content.sound = .default
        content.categoryIdentifier = "timer_complete"
        
        // Calculate time interval
        let timeInterval = endTime.timeIntervalSinceNow
        guard timeInterval > 0 else { return }
        
        // Create trigger
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: "timer_completion", content: content, trigger: trigger)
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    // MARK: - State Persistence
    
    private func persistTimerState() {
        if let endTime = endTime {
            persistedEndTime = endTime.timeIntervalSince1970
        } else {
            persistedEndTime = 0
        }
        
        persistedPausedTime = pausedRemainingTime
        persistedIsRunning = isRunning
        persistedIsPaused = isPaused
        persistedSelectedMinutes = selectedMinutes
    }
    
    private func restoreTimerState() {
        // Restore selected minutes
        selectedMinutes = persistedSelectedMinutes
        
        // Check if timer was running
        if persistedIsRunning && persistedEndTime > 0 {
            let savedEndTime = Date(timeIntervalSince1970: persistedEndTime)
            
            // Check if timer should still be running
            if savedEndTime.timeIntervalSinceNow > 0 {
                // Timer is still valid
                endTime = savedEndTime
                isRunning = true
                isPaused = false
                
                // Restart UI updates
                startInternalTimer()
                
                // Restart extended session
                startExtendedSession()
            } else {
                // Timer completed while app was closed
                checkTimerCompletion()
            }
        } else if persistedIsPaused && persistedPausedTime > 0 {
            // Timer was paused
            pausedRemainingTime = persistedPausedTime
            isPaused = true
            isRunning = false
        }
    }
    
    private func checkTimerCompletion() {
        // Check if timer completed while app was in background
        if persistedIsRunning && persistedEndTime > 0 {
            let savedEndTime = Date(timeIntervalSince1970: persistedEndTime)
            
            if savedEndTime.timeIntervalSinceNow <= 0 {
                // Timer completed
                completeTimer()
            }
        }
    }
    
    // MARK: - Extended Runtime Session
    
    private func startExtendedSession() {
        // End any existing session
        extendedSession?.invalidate()
        
        // Setup handler callback
        sessionHandler.onWillExpire = {
            persistTimerState()
        }
        
        // Create new session
        extendedSession = WKExtendedRuntimeSession()
        extendedSession?.delegate = sessionHandler
        extendedSession?.start()
    }
}

// MARK: - Extended Runtime Session Handler

class ExtendedRuntimeSessionHandler: NSObject, WKExtendedRuntimeSessionDelegate {
    var onWillExpire: (() -> Void)?
    
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session started")
    }
    
    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("Extended runtime session will expire")
        onWillExpire?()
    }
    
    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("Extended runtime session invalidated: \(reason)")
        if let error = error {
            print("Error: \(error)")
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Extracted subviews to simplify type-checking
private extension ContentView {
    enum CornerAnchor { case topLeft, topRight, bottomLeft, bottomRight }

    // Anchor a circular control to the visual corners by subtracting its radius and a small edge padding
    func cornerPoint(_ anchor: CornerAnchor, in size: CGSize, controlRadius: CGFloat, edgePadding: CGFloat) -> CGPoint {
        let w = size.width
        let h = size.height
        let xInset = controlRadius + edgePadding + 3 // Add extra horizontal inset
        let yInset = controlRadius + edgePadding
        switch anchor {
        case .topLeft:
            return CGPoint(x: xInset, y: yInset)
        case .topRight:
            return CGPoint(x: w - xInset, y: yInset)
        case .bottomLeft:
            return CGPoint(x: xInset, y: h - yInset)
        case .bottomRight:
            return CGPoint(x: w - xInset, y: h - yInset)
        }
    }
    @ViewBuilder var mainScrollContent: some View {
        VStack(spacing: 8) {
            timerDisplay
            if isIdle && !hasSetDurationOnce {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                    Text("Tap time to set duration")
                }
                .font(currentTheme.labelFont)
                .foregroundColor(currentTheme.primaryColor.opacity(0.35))
                .padding(.top, 2)
                .offset(y: -10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double tap to cycle activity type
            if isIdle {
                cycleActivityType()
                // Show visual feedback
                withAnimation(.easeInOut(duration: 0.3)) {
                    showActivityTypeChange = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showActivityTypeChange = false
                    }
                }
            }
        }
        .onTapGesture {
            if isIdle && currentTheme != .terminal {
                hasSetDurationOnce = true
                showDurationPicker = true
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            showThemePicker = true
        }
        .padding(.horizontal)
        .padding(.bottom, 38)
    }

    @ViewBuilder var timerDisplay: some View {
        switch currentTheme {
        case .terminal:
            TerminalTimerView(
                timeRemaining: timeRemaining,
                isRunning: isRunning,
                sessionsCompleted: sessionsCompleted,
                totalDuration: totalDuration,
                isIdle: isIdle,
                currentThemeName: currentTheme.rawValue,
                onStartPause: { toggleTimer() },
                onSetDuration: {
                    if isIdle {
                        hasSetDurationOnce = true
                        showDurationPicker = true
                    }
                },
                onChangeTheme: { showThemePicker = true }
            )
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 0, green: 1, blue: 0).opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: Color(red: 0, green: 1, blue: 0).opacity(0.2), radius: 10)
            .padding(.vertical, 10)

        case .lcd:
            LCDTimerView(
                timeRemaining: timeRemaining,
                isRunning: isRunning,
                progress: progress
            )
            .padding(.vertical, 10)

        case .retroDigital:
            RetroDigitalTimerView(
                timeRemaining: timeRemaining,
                isRunning: isRunning,
                progress: progress
            )
            .padding(.vertical, 10)

        default:
            circularTimerView
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder var circularTimerView: some View {
        let circleSize: CGFloat = 140 // Increased from 120
        
        ZStack {
            Circle()
                .stroke(currentTheme.primaryColor.opacity(currentTheme == .minimal ? 0.15 : 0.2), lineWidth: currentTheme == .neon ? 6 : (currentTheme == .minimal ? 2 : 3))
                .frame(width: circleSize, height: circleSize)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        currentTheme == .minimal ? 
                            LinearGradient(colors: [currentTheme.primaryColor.opacity(0.5)], startPoint: .leading, endPoint: .trailing) :
                            currentTheme.progressGradient,
                        style: StrokeStyle(lineWidth: currentTheme == .neon ? 6 : (currentTheme == .minimal ? 2 : 3), lineCap: .round)
                    )
                    .frame(width: circleSize, height: circleSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.5), value: progress)

                if currentTheme.hasGlow {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            currentTheme.primaryColor.opacity(0.3),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: circleSize, height: circleSize)
                        .rotationEffect(.degrees(-90))
                        .blur(radius: currentTheme == .neon ? 8 : 4)
                }

                VStack(spacing: currentTheme == .minimal ? 2 : 5) {
                    // Show activity description for minimal theme, like macOS
                    if currentTheme == .minimal {
                        VStack(spacing: 0) {
                            let (line1, line2) = activityType.displayText
                            if !line1.isEmpty {
                                Text(line1)
                                    .font(.system(size: 11, weight: .regular, design: .default))
                                    .foregroundColor(currentTheme.primaryColor.opacity(0.5))
                                    .tracking(1.2)
                            }
                            Text(line2)
                                .font(.system(size: 11, weight: .regular, design: .default))
                                .foregroundColor(currentTheme.primaryColor.opacity(0.5))
                                .tracking(1.2)
                            Text("\(Int(progress * 100))%")
                                .font(.system(size: 10, weight: .regular, design: .default))
                                .foregroundColor(currentTheme.primaryColor.opacity(0.35))
                                .padding(.top, 1)
                        }
                        .padding(.bottom, 4)
                    }
                    
                    if currentTheme == .neon {
                        HStack(spacing: 2) {
                            Text(String(format: "%02d", timeRemaining / 60))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(currentTheme.primaryColor)
                                .shadow(color: currentTheme.primaryColor, radius: 15)

                            Text(":")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundColor(currentTheme.accentColor)
                                .shadow(color: currentTheme.accentColor, radius: 10)
                                .offset(y: -2)

                            Text(String(format: "%02d", timeRemaining % 60))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(currentTheme.primaryColor)
                                .shadow(color: currentTheme.primaryColor, radius: 15)
                        }
                    } else if currentTheme == .glow {
                        Text(timeString(from: timeRemaining))
                            .font(.system(size: 40, weight: .medium, design: .default))
                            .foregroundColor(currentTheme.primaryColor)
                            .shadow(color: currentTheme.primaryColor, radius: 20)
                            .shadow(color: currentTheme.accentColor, radius: 10)
                            .blur(radius: 0.5)
                            .overlay(
                                Text(timeString(from: timeRemaining))
                                    .font(.system(size: 40, weight: .medium, design: .default))
                                    .foregroundColor(.white)
                            )
                    } else {
                        Text(timeString(from: timeRemaining))
                            .font(currentTheme == .minimal ? 
                                  .system(size: 38, weight: .light, design: .default) :
                                  .system(size: 40, weight: .medium, design: .default))
                            .foregroundColor(currentTheme.primaryColor)
                    }

                    // Only show session dots for non-minimal themes
                    if currentTheme != .minimal {
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { index in
                                Circle()
                                    .fill(index < (sessionsCompleted % 4) ?
                                          currentTheme.accentColor :
                                          currentTheme.primaryColor.opacity(0.2))
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }
            }
        }
    }
}
// MARK: - Computed overlay views
private extension ContentView {
    // terminalBottomBar removed; TerminalTimerView now handles terminal commands
}

// Reusable corner button to ensure identical sizing/visuals across corners
private struct CornerCircleButton: View {
    let icon: String
    let size: CGFloat
    let fill: Color
    let border: Color
    let iconColor: Color
    let shadowColor: Color
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // For minimal theme, use a more subtle style
                if fill == WatchTheme.minimal.buttonColor {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.08))
                        .frame(width: size, height: size * 0.7)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                        )
                } else {
                    Circle()
                        .fill(fill)
                        .frame(width: size, height: size)
                        .shadow(color: shadowColor, radius: 6)
                    Circle()
                        .stroke(border, lineWidth: 1)
                        .frame(width: size, height: size)
                }
                
                Image(systemName: icon)
                    .font(.system(size: max(10, size * 0.3), weight: .regular))
                    .foregroundColor(fill == WatchTheme.minimal.buttonColor ? Color.gray.opacity(0.7) : iconColor)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
