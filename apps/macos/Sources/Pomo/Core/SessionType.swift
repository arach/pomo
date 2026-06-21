import SwiftUI
import HudsonUI

/// The kind of interval the timer is counting down. A clean classic-Pomodoro
/// model: focus → short break → (every `longBreakInterval`th) long break.
enum SessionType: String, CaseIterable, Codable, Identifiable {
    case focus
    case shortBreak
    case longBreak

    var id: String { rawValue }

    /// Uppercase label shown on the watchfaces.
    var label: String {
        switch self {
        case .focus:      return "FOCUS"
        case .shortBreak: return "BREAK"
        case .longBreak:  return "LONG BREAK"
        }
    }

    /// Compact label for the menu bar / tight chrome.
    var shortLabel: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Break"
        case .longBreak:  return "Long Break"
        }
    }

    var symbolName: String {
        switch self {
        case .focus:      return "brain.head.profile"
        case .shortBreak: return "cup.and.saucer"
        case .longBreak:  return "figure.walk"
        }
    }

    /// Chrome accent used by the Minimal face + menu, mapped onto Hudson tints.
    var tint: HudTint {
        switch self {
        case .focus:      return .green
        case .shortBreak: return .cyan
        case .longBreak:  return .violet
        }
    }

    var isBreak: Bool { self != .focus }
}
