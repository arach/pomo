//
//  ContentView.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    @State private var timeRemaining = 25 * 60 // 25 minutes in seconds
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var currentTheme: WatchTheme = .minimal
    @State private var showThemePicker = false
    @State private var showDurationPicker = false
    @State private var sessionsCompleted = 0
    @State private var selectedMinutes = 25
    
    
    var totalDuration: Int {
        selectedMinutes * 60
    }
    
    var progress: Double {
        Double(totalDuration - timeRemaining) / Double(totalDuration)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                currentTheme.backgroundColor
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Settings bar
                        HStack(spacing: 12) {
                            // Duration picker
                            Button(action: { showDurationPicker = true }) {
                                Label(String(format: "%d min", selectedMinutes), systemImage: "timer")
                                    .font(.system(size: 12))
                                    .foregroundColor(currentTheme.accentColor.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Theme switcher
                            Button(action: { showThemePicker = true }) {
                                Image(systemName: "paintbrush.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(currentTheme.accentColor.opacity(0.7))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal)
                        .padding(.top, 5)
                
                // Theme-specific timer display
                if currentTheme == .terminal {
                    // Terminal-specific view
                    TerminalTimerView(
                        timeRemaining: timeRemaining,
                        isRunning: isRunning,
                        sessionsCompleted: sessionsCompleted
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
                } else if currentTheme == .lcd {
                    // LCD display view
                    LCDTimerView(
                        timeRemaining: timeRemaining,
                        isRunning: isRunning,
                        progress: progress
                    )
                    .padding(.vertical, 10)
                } else if currentTheme == .retroDigital {
                    // Retro digital clock view
                    RetroDigitalTimerView(
                        timeRemaining: timeRemaining,
                        isRunning: isRunning,
                        progress: progress
                    )
                    .padding(.vertical, 10)
                } else {
                    // Circular progress for minimal and neon themes
                    ZStack {
                        // Background circle
                        Circle()
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: currentTheme == .neon ? 6 : 3)
                            .frame(width: 140, height: 140)
                        
                        // Progress circle
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                currentTheme.progressGradient,
                                style: StrokeStyle(lineWidth: currentTheme == .neon ? 6 : 3, lineCap: .round)
                            )
                            .frame(width: 140, height: 140)
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: progress)
                        
                        if currentTheme.hasGlow {
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    currentTheme.primaryColor.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .frame(width: 140, height: 140)
                                .rotationEffect(.degrees(-90))
                                .blur(radius: currentTheme == .neon ? 8 : 4)
                        }
                        
                        // Time display inside circle
                        VStack(spacing: 5) {
                            if currentTheme == .neon {
                                // Neon digital display
                                HStack(spacing: 2) {
                                    Text(String(format: "%02d", timeRemaining / 60))
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundColor(currentTheme.primaryColor)
                                        .shadow(color: currentTheme.primaryColor, radius: 15)
                                    
                                    Text(":")
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                        .foregroundColor(currentTheme.accentColor)
                                        .shadow(color: currentTheme.accentColor, radius: 10)
                                        .offset(y: -2)
                                    
                                    Text(String(format: "%02d", timeRemaining % 60))
                                        .font(.system(size: 44, weight: .bold, design: .rounded))
                                        .foregroundColor(currentTheme.primaryColor)
                                        .shadow(color: currentTheme.primaryColor, radius: 15)
                                }
                            } else if currentTheme == .glow {
                                // Glow theme with pulsing effect
                                Text(timeString(from: timeRemaining))
                                    .font(currentTheme.timerFont)
                                    .foregroundColor(currentTheme.primaryColor)
                                    .shadow(color: currentTheme.primaryColor, radius: 20)
                                    .shadow(color: currentTheme.accentColor, radius: 10)
                                    .blur(radius: 0.5)
                                    .overlay(
                                        Text(timeString(from: timeRemaining))
                                            .font(currentTheme.timerFont)
                                            .foregroundColor(.white)
                                    )
                            } else {
                                // Minimal clean display
                                Text(timeString(from: timeRemaining))
                                    .font(currentTheme.timerFont)
                                    .foregroundColor(currentTheme.primaryColor)
                            }
                            
                            // Session dots
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
                    .padding(.vertical, 10)
                }
                        
                        // Play/Pause button with theme colors
                        Button(action: toggleTimer) {
                            ZStack {
                                Circle()
                                    .fill(isRunning ? currentTheme.accentColor : currentTheme.buttonColor)
                                    .frame(width: 50, height: 50)
                                
                                if currentTheme.hasGlow {
                                    Circle()
                                        .stroke(currentTheme.accentColor.opacity(0.5), lineWidth: 1)
                                        .frame(width: 50, height: 50)
                                        .shadow(color: currentTheme.accentColor.opacity(0.3), radius: currentTheme.glowRadius / 2)
                                }
                                
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(currentTheme == .minimal ? currentTheme.backgroundColor : .white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.bottom, 10)
                    }
                    .padding(.horizontal)
                }
            }
            .sheet(isPresented: $showThemePicker) {
                ThemePickerView(currentTheme: $currentTheme)
            }
            .sheet(isPresented: $showDurationPicker) {
                DurationPickerView(selectedMinutes: $selectedMinutes, timeRemaining: $timeRemaining)
            }
        }
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
                    // Add haptic feedback
                    WKInterfaceDevice.current().play(.success)
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
}

#Preview {
    ContentView()
}
