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
    @State private var cursorVisible = true
    @State private var terminalLines: [String] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Terminal header
            Text("> pomo --watch")
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
                
                // Blinking cursor
                Text(cursorVisible ? "_" : " ")
                    .font(.system(size: 28, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0, green: 1, blue: 0))
                    .animation(.none, value: cursorVisible)
            }
            
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
        }
        .onAppear {
            startCursorBlink()
        }
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
        let totalDuration = 25 * 60 // Default 25 minutes
        return Double(totalDuration - timeRemaining) / Double(totalDuration)
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
        timeRemaining: 1234,
        isRunning: true,
        sessionsCompleted: 2
    )
    .padding()
    .background(Color.black)
}