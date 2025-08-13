//
//  Theme.swift
//  PomoWatch Watch App
//
//  Created by Arach Tchoupani on 2025-08-13.
//

import SwiftUI

enum WatchTheme: String, CaseIterable {
    case minimal = "Minimal"
    case terminal = "Terminal"
    case neon = "Neon"
    case retroDigital = "Retro Digital"
    case lcd = "LCD"
    case glow = "Glow"
    
    var backgroundColor: Color {
        switch self {
        case .minimal:
            return Color(red: 0.1, green: 0.1, blue: 0.1) // #1a1a1a
        case .terminal:
            return Color(red: 0, green: 0, blue: 0).opacity(0.98) // Terminal black
        case .neon:
            return Color(red: 0.04, green: 0.04, blue: 0.06) // #0a0a0f
        case .retroDigital:
            return Color(red: 0.05, green: 0.05, blue: 0.08) // Dark blue-black
        case .lcd:
            return Color(red: 0.55, green: 0.6, blue: 0.45) // Classic LCD green-gray
        case .glow:
            return Color(red: 0.02, green: 0.02, blue: 0.05) // Deep space blue
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .minimal:
            return Color.white
        case .terminal:
            return Color(red: 0, green: 1, blue: 0) // #00ff00 - Terminal green
        case .neon:
            return Color(red: 1, green: 0, blue: 1) // #ff00ff - Magenta
        case .retroDigital:
            return Color(red: 1, green: 0.2, blue: 0.1) // Red-orange LED
        case .lcd:
            return Color(red: 0.1, green: 0.15, blue: 0.05) // Dark LCD segments
        case .glow:
            return Color(red: 0.4, green: 0.8, blue: 1) // Soft blue glow
        }
    }
    
    var accentColor: Color {
        switch self {
        case .minimal:
            return Color(red: 0.29, green: 0.62, blue: 1) // #4a9eff - Blue
        case .terminal:
            return Color(red: 0, green: 1, blue: 0) // Same as primary for terminal
        case .neon:
            return Color(red: 0, green: 1, blue: 1) // #00ffff - Cyan
        case .retroDigital:
            return Color(red: 1, green: 0.6, blue: 0) // Amber segments
        case .lcd:
            return Color(red: 0.2, green: 0.25, blue: 0.1) // Darker LCD
        case .glow:
            return Color(red: 1, green: 0.4, blue: 0.8) // Pink glow
        }
    }
    
    var buttonColor: Color {
        switch self {
        case .minimal:
            return Color(red: 0.29, green: 0.62, blue: 1) // Blue accent
        case .terminal:
            return Color(red: 0, green: 1, blue: 0).opacity(0.2) // Dim green
        case .neon:
            return Color(red: 1, green: 0, blue: 1).opacity(0.8) // Magenta
        case .retroDigital:
            return Color(red: 0.8, green: 0.1, blue: 0.05) // Red button
        case .lcd:
            return Color(red: 0.3, green: 0.35, blue: 0.25) // LCD button
        case .glow:
            return Color(red: 0.6, green: 0.4, blue: 1) // Purple glow
        }
    }
    
    var fontDesign: Font.Design {
        switch self {
        case .minimal:
            return .default // Inter-like
        case .terminal:
            return .monospaced // SF Mono
        case .neon:
            return .rounded // Futuristic
        case .retroDigital:
            return .monospaced // Digital clock
        case .lcd:
            return .monospaced // LCD segments
        case .glow:
            return .rounded // Soft glow
        }
    }
    
    var timerFont: Font {
        switch self {
        case .minimal:
            return .system(size: 40, weight: .light, design: .default)
        case .terminal:
            return .system(size: 28, weight: .regular, design: .monospaced)
        case .neon:
            return .system(size: 42, weight: .bold, design: .rounded)
        case .retroDigital:
            return .system(size: 48, weight: .heavy, design: .monospaced)
        case .lcd:
            return .system(size: 36, weight: .bold, design: .monospaced)
        case .glow:
            return .system(size: 38, weight: .medium, design: .rounded)
        }
    }
    
    var labelFont: Font {
        switch self {
        case .minimal:
            return .system(size: 12, weight: .medium, design: .default)
        case .terminal:
            return .system(size: 10, weight: .regular, design: .monospaced)
        case .neon:
            return .system(size: 11, weight: .semibold, design: .rounded)
        case .retroDigital:
            return .system(size: 10, weight: .bold, design: .monospaced)
        case .lcd:
            return .system(size: 11, weight: .medium, design: .monospaced)
        case .glow:
            return .system(size: 12, weight: .light, design: .rounded)
        }
    }
    
    var hasGlow: Bool {
        switch self {
        case .minimal, .lcd:
            return false
        case .terminal, .neon, .retroDigital, .glow:
            return true
        }
    }
    
    var glowRadius: CGFloat {
        switch self {
        case .minimal:
            return 0
        case .terminal:
            return 6
        case .neon:
            return 10
        case .retroDigital:
            return 8
        case .lcd:
            return 0
        case .glow:
            return 15
        }
    }
    
    var progressGradient: LinearGradient {
        switch self {
        case .minimal:
            return LinearGradient(
                colors: [accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .terminal:
            return LinearGradient(
                colors: [primaryColor, primaryColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neon:
            return LinearGradient(
                colors: [primaryColor, accentColor, primaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .retroDigital:
            return LinearGradient(
                colors: [primaryColor, accentColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .lcd:
            return LinearGradient(
                colors: [primaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .glow:
            return LinearGradient(
                colors: [primaryColor, accentColor, primaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}