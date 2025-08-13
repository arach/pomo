//
//  LCDTimerView.swift
//  PomoWatch Watch App
//
//  LCD-style timer display with segmented digits
//

import SwiftUI

struct LCDTimerView: View {
    let timeRemaining: Int
    let isRunning: Bool
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            // LCD Display panel
            ZStack {
                // LCD background with shadow effect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.55, green: 0.6, blue: 0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)
                
                VStack(spacing: 4) {
                    // Status indicator
                    HStack {
                        Text("TIMER")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.05))
                        
                        Spacer()
                        
                        if isRunning {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.05))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 4)
                    
                    // Main time display with LCD segments effect
                    ZStack {
                        // Ghost segments (all segments visible but faded)
                        Text("88:88")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.45, green: 0.5, blue: 0.35).opacity(0.15))
                        
                        // Active segments
                        Text(timeString)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.05))
                    }
                    
                    // Progress bar LCD style
                    HStack(spacing: 1) {
                        ForEach(0..<10, id: \.self) { index in
                            Rectangle()
                                .fill(index < Int(progress * 10) ? 
                                      Color(red: 0.1, green: 0.15, blue: 0.05) : 
                                      Color(red: 0.45, green: 0.5, blue: 0.35).opacity(0.2))
                                .frame(width: 12, height: 4)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
            .frame(height: 100)
        }
    }
    
    private var timeString: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct RetroDigitalTimerView: View {
    let timeRemaining: Int
    let isRunning: Bool
    let progress: Double
    @State private var colonVisible = true
    
    var body: some View {
        VStack(spacing: 10) {
            // Retro digital clock display
            ZStack {
                // Background with scan lines effect
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.05, green: 0.05, blue: 0.08))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.2),
                                Color.clear,
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                
                // LED segments
                HStack(spacing: 4) {
                    // Minutes
                    DigitView(digit: (timeRemaining / 60) / 10)
                    DigitView(digit: (timeRemaining / 60) % 10)
                    
                    // Colon separator
                    VStack(spacing: 8) {
                        Circle()
                            .fill(colonVisible && isRunning ? 
                                  Color(red: 1, green: 0.2, blue: 0.1) : 
                                  Color(red: 0.3, green: 0.05, blue: 0.02))
                            .frame(width: 4, height: 4)
                            .shadow(color: Color(red: 1, green: 0.2, blue: 0.1), 
                                   radius: colonVisible && isRunning ? 4 : 0)
                        
                        Circle()
                            .fill(colonVisible && isRunning ? 
                                  Color(red: 1, green: 0.2, blue: 0.1) : 
                                  Color(red: 0.3, green: 0.05, blue: 0.02))
                            .frame(width: 4, height: 4)
                            .shadow(color: Color(red: 1, green: 0.2, blue: 0.1), 
                                   radius: colonVisible && isRunning ? 4 : 0)
                    }
                    
                    // Seconds
                    DigitView(digit: (timeRemaining % 60) / 10)
                    DigitView(digit: (timeRemaining % 60) % 10)
                }
                .padding()
            }
            .frame(height: 90)
            .onAppear {
                startColonBlink()
            }
            
            // LED progress dots
            HStack(spacing: 3) {
                ForEach(0..<15, id: \.self) { index in
                    Circle()
                        .fill(index < Int(progress * 15) ? 
                              Color(red: 1, green: 0.6, blue: 0) : 
                              Color(red: 0.2, green: 0.1, blue: 0))
                        .frame(width: 6, height: 6)
                        .shadow(color: Color(red: 1, green: 0.6, blue: 0), 
                               radius: index < Int(progress * 15) ? 3 : 0)
                }
            }
        }
    }
    
    private func startColonBlink() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            colonVisible.toggle()
        }
    }
}

struct DigitView: View {
    let digit: Int
    
    var body: some View {
        ZStack {
            // Ghost segments
            Text("8")
                .font(.system(size: 42, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 0.3, green: 0.05, blue: 0.02).opacity(0.3))
            
            // Active digit
            Text("\(digit)")
                .font(.system(size: 42, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(red: 1, green: 0.2, blue: 0.1))
                .shadow(color: Color(red: 1, green: 0.2, blue: 0.1), radius: 6)
        }
    }
}