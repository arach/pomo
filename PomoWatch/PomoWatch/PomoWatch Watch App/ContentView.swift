//
//  ContentView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI
import WatchKit
import AVFoundation

struct ContentView: View {
    @State private var timeRemaining = 25 * 60 // 25 minutes in seconds
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var currentTheme: WatchTheme = .minimal
    @State private var showThemePicker = false
    @State private var showDurationPicker = false
    @State private var sessionsCompleted = 0
    @State private var selectedMinutes = 25
    @State private var activityType: ActivityType = .focus
    @State private var showActivityTypeChange = false
    @State private var showConfetti = false
    @AppStorage("hasSetDurationOnce") private var hasSetDurationOnce: Bool = false
    
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
    
    
    var totalDuration: Int {
        selectedMinutes * 60
    }
    
    var progress: Double {
        Double(totalDuration - timeRemaining) / Double(totalDuration)
    }
    
    var isIdle: Bool {
        !isRunning && timeRemaining == totalDuration
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    mainScrollContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Geometry-anchored corner controls (ignore safe areas, anchor by screen radius)
            .overlay {
                GeometryReader { proxy in
                    let size = proxy.size
                    let minDim = min(size.width, size.height)
                    // Pull in by a handful of pixels; scale slightly with watch size and add a few extra px
                    let edgePadding: CGFloat = max(6, minDim * 0.03) + 6
                    // Mildly responsive button radii for smaller watches
                    let smallRadius: CGFloat = max(14, min(17, minDim * 0.085)) // ~28–34pt diameter
                    let largeRadius: CGFloat = smallRadius // Keep start button same size as others
                    
                    ZStack {
                        if currentTheme != .terminal {
                            // Bottom-left: reset (long-press in Minimal theme resets first-time hint)
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
                            
                            // Bottom-right: start/pause
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
                    }
                }
                .ignoresSafeArea()
            }
            // Terminal theme now renders its own command UI; no global bottom bar
            
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView(currentTheme: $currentTheme)
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerView(selectedMinutes: $selectedMinutes, timeRemaining: $timeRemaining)
            }
            // Activity type change overlay
            .overlay(alignment: .top) {
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
            // Confetti overlay
            .overlay {
                if showConfetti {
                    ConfettiView(isShowing: $showConfetti)
                        .allowsHitTesting(false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerStartedFromIntent)) { notification in
                if let userInfo = notification.userInfo,
                   let minutes = userInfo["minutes"] as? Int,
                   let themeString = userInfo["theme"] as? String,
                   let theme = WatchTheme(rawValue: themeString) {
                    selectedMinutes = minutes
                    timeRemaining = minutes * 60
                    currentTheme = theme
                    isRunning = true
                    startInternalTimer()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerPausedFromIntent)) { _ in
                pauseTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerResumedFromIntent)) { _ in
                resumeTimer()
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerStoppedFromIntent)) { _ in
                stopTimer()
            }
        }
    }
    
    private func startInternalTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                // Timer finished
                timer?.invalidate()
                timer = nil
                isRunning = false
                sessionsCompleted += 1
                timeRemaining = totalDuration
                
                // Trigger completion effects
                triggerCompletionEffects()
            }
        }
    }
    
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func resumeTimer() {
        isRunning = true
        startInternalTimer()
    }
    
    private func stopTimer() {
        isRunning = false
        timeRemaining = selectedMinutes * 60
        timer?.invalidate()
        timer = nil
    }
    
    private func toggleTimer() {
        if isRunning {
            // Pause
            timer?.invalidate()
            timer = nil
        } else {
            // Start
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    // Timer finished
                    timer?.invalidate()
                    timer = nil
                    isRunning = false
                    sessionsCompleted += 1
                    timeRemaining = totalDuration // Reset
                    
                    // Trigger completion effects
                    triggerCompletionEffects()
                }
            }
        }
        isRunning.toggle()
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
            timeRemaining = selectedMinutes * 60
            
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
