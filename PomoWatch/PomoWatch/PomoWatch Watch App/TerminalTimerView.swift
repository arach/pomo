//
//  TerminalTimerView.swift
//  PomoWatch Watch App
//
//  Terminal-style timer display with blinking cursor
//

import SwiftUI

struct TerminalTimerView: View {
    let timeRemaining: Int
    let isRunning: Bool
    let sessionsCompleted: Int
    let totalDuration: Int
    let isIdle: Bool
    let currentThemeName: String
    let onStartPause: () -> Void
    let onSetDuration: () -> Void
    let onChangeTheme: () -> Void
    @State private var cursorVisible = true
    @State private var terminalLines: [String] = []
    @State private var selectedOption: Int = 0
    @State private var crownValue: Double = 0
    @FocusState private var crownFocused: Bool
    @State private var durationJustChanged: Bool = false
    @State private var activeSelectedOption: Int = 0
    @State private var activeCrownValue: Double = 0
    @FocusState private var activeCrownFocused: Bool
    @State private var sessionPID: Int = Int.random(in: 1000...9999)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isIdle {
                // Idle "help" screen inside terminal body (no active timer UI)
                HStack(spacing: 2) {
                    Text("> pomo start")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    Text(cursorVisible ? "_" : " ")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                        .animation(.none, value: cursorVisible)
                }
                Divider()
                    .background(Color(red: 0, green: 1, blue: 0).opacity(0.3))
                    .padding(.vertical, 2)
                Group {
                    Text("SETTINGS:")
                        .font(.system(size: 9, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.75))
                    Text("themeName: \"\(currentThemeName)\"")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    Text("duration: \(durationMinutes)m")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(durationJustChanged ? Color.black : Color(red: 0, green: 1, blue: 0))
                        .padding(.horizontal, durationJustChanged ? 4 : 0)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(durationJustChanged ? Color(red: 0, green: 1, blue: 0) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color(red: 0, green: 1, blue: 0).opacity(durationJustChanged ? 0.6 : 0), lineWidth: 1)
                        )
                }
                Divider()
                    .background(Color(red: 0, green: 1, blue: 0).opacity(0.3))
                    .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 2) {
                    optionRow(index: 0, label: "start", isSelected: selectedOption == 0, action: onStartPause)
                    optionRow(index: 1, label: "set duration", isSelected: selectedOption == 1, action: onSetDuration)
                    optionRow(index: 2, label: "change theme", isSelected: selectedOption == 2, action: onChangeTheme)
                }
                .focusable(true)
                .focused($crownFocused)
                .digitalCrownRotation(
                    $crownValue,
                    from: 0,
                    through: 2,
                    by: 1,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: crownValue) { _, newValue in
                    let newIndex = Int(round(newValue))
                    if newIndex != selectedOption {
                        selectedOption = max(0, min(2, newIndex))
                    }
                }
                .onAppear { crownFocused = true }
            } else {
                // Active run terminal with timer/progress
                // Terminal header
                Text("> pomo start")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.7))
                Text("SESSION: \(sessionsCompleted + 1)")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.7))
                Divider()
                    .background(Color(red: 0, green: 1, blue: 0).opacity(0.3))
                    .padding(.vertical, 2)
                // Main timer display with cursor
                HStack(spacing: 0) {
                    Text("TIME: ")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.8))
                    Text(timeString)
                        .font(.system(size: 28, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    Text(cursorVisible ? "_" : " ")
                        .font(.system(size: 28, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                        .animation(.none, value: cursorVisible)
                }
                .contentShape(Rectangle())
                .onTapGesture { onSetDuration() }
                .onLongPressGesture(minimumDuration: 0.5) { onSetDuration() }
                // Status line
                Text(statusLine)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.6))
                    .padding(.top, 4)
                // ASCII progress bar
                HStack(spacing: 0) {
                    Text("[")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.5))
                    ForEach(0..<20, id: \.self) { index in
                        Text(progressChar(at: index))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.8))
                    }
                    Text("]")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.5))
                }
                .padding(.top, 4)
                // Progress percentage
                Text("\(Int(progress * 100))% COMPLETE")
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0).opacity(0.6))
                    .padding(.top, 2)
                Divider()
                    .background(Color(red: 0, green: 1, blue: 0).opacity(0.3))
                    .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 2) {
                    activeOptionRow(index: 0, label: isRunning ? "pause" : "resume", isSelected: activeSelectedOption == 0, action: onStartPause)
                    activeOptionRow(index: 1, label: "set duration", isSelected: activeSelectedOption == 1, action: onSetDuration)
                }
                .focusable(true)
                .focused($activeCrownFocused)
                .digitalCrownRotation(
                    $activeCrownValue,
                    from: 0,
                    through: 1,
                    by: 1,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
                .onChange(of: activeCrownValue) { _, newValue in
                    let newIndex = Int(round(newValue))
                    if newIndex != activeSelectedOption {
                        activeSelectedOption = max(0, min(1, newIndex))
                    }
                }
                .onAppear { activeCrownFocused = true }
            }
        }
        .onAppear { startCursorBlink() }
        .onChange(of: totalDuration) { _, _ in
            // Flash the duration line and re-enable crown focus after picker dismissal
            durationJustChanged = true
            crownFocused = true
            withAnimation(.easeInOut(duration: 0.25)) { }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    durationJustChanged = false
                }
            }
        }
        .onChange(of: isIdle) { _, nowIdle in
            if nowIdle {
                crownFocused = true
            } else {
                activeCrownFocused = true
            }
        }
        .onChange(of: isRunning) { oldRunning, newRunning in
            // Generate new PID when starting a fresh timer session
            if !oldRunning && newRunning && timeRemaining == totalDuration {
                sessionPID = Int.random(in: 1000...9999)
            }
        }
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var statusLine: String {
        if isRunning {
            return "STATUS: RUNNING [PID: \(sessionPID)]"
        } else {
            return "STATUS: PAUSED [IDLE]"
        }
    }
    
    private var progress: Double {
        return Double(totalDuration - timeRemaining) / Double(totalDuration)
    }
    
    private var durationMinutes: Int {
        return max(1, totalDuration / 60)
    }

    @ViewBuilder
    private func optionRow(index: Int, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 4) {
                Text(isSelected ? ">" : " ")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0))
                Text("\(index + 1)/ \(label)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(isSelected ? Color.black : Color(red: 0, green: 1, blue: 0))
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color(red: 0, green: 1, blue: 0) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0, green: 1, blue: 0).opacity(isSelected ? 0.6 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func activeOptionRow(index: Int, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 4) {
                Text(isSelected ? ">" : " ")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0))
                Text(label)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(isSelected ? Color.black : Color(red: 0, green: 1, blue: 0))
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isSelected ? Color(red: 0, green: 1, blue: 0) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(red: 0, green: 1, blue: 0).opacity(isSelected ? 0.6 : 0.25), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func progressChar(at index: Int) -> String {
        let filledCount = Int(progress * 20)
        if index < filledCount {
            return "█"
        } else if index == filledCount {
            return "▓"
        } else {
            return "░"
        }
    }
    
    private func startCursorBlink() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            cursorVisible.toggle()
        }
    }
}

#Preview {
    TerminalTimerView(
        timeRemaining: 25 * 60,
        isRunning: false,
        sessionsCompleted: 2,
        totalDuration: 25 * 60,
        isIdle: true,
        currentThemeName: "Terminal",
        onStartPause: {},
        onSetDuration: {},
        onChangeTheme: {}
    )
    .padding()
    .background(Color.black)
}