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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if isIdle {
                // Idle "help" screen inside terminal body (no active timer UI)
                HStack(spacing: 2) {
                    Text("> pomo --help")
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
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                }
                Divider()
                    .background(Color(red: 0, green: 1, blue: 0).opacity(0.3))
                    .padding(.vertical, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Button(action: onStartPause) {
                        Text("1/ start")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    }
                    Button(action: onSetDuration) {
                        Text("2/ set duration")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    }
                    Button(action: onChangeTheme) {
                        Text("3/ change theme")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    }
                }
            } else {
                // Active run terminal with timer/progress
                // Terminal header
                Text("> pomo -h")
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
                Button(action: onStartPause) {
                    Text("PAUSE")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(red: 0, green: 1, blue: 0))
                }
            }
        }
        .onAppear { startCursorBlink() }
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private var statusLine: String {
        if isRunning {
            return "STATUS: RUNNING [PID: \(Int.random(in: 1000...9999))]"
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